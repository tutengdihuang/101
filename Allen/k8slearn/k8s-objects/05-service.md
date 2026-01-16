# Service 与网络 - K8s 的"电话总机"

> Pod 会死会生，IP 会变，但 Service 永远在那里

## 一个困扰

假设你有一个 Web 应用，后端是 3 个 Pod 组成的 API 服务。问题来了：

- Pod 的 IP 是动态分配的，每次重启都可能变
- Pod 可能被调度到不同的节点
- Pod 可能随时被销毁和重建

前端怎么知道该访问哪个 IP？难道每次 Pod 重启都要改配置？

这就像你要打电话给一家公司，但公司员工的手机号天天换。你需要的是一个**总机号码**——不管员工怎么换，总机号码不变。

**Service 就是 K8s 的"总机"**：提供稳定的访问入口，自动把请求转发到后端的 Pod。

---

## Service 的工作原理

```
                    ┌─────────────┐
                    │   Service   │
                    │ 10.96.0.100 │  ← 稳定的 ClusterIP
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
      ┌─────────┐    ┌─────────┐    ┌─────────┐
      │  Pod 1  │    │  Pod 2  │    │  Pod 3  │
      │10.244.1.5│   │10.244.2.8│   │10.244.3.2│
      └─────────┘    └─────────┘    └─────────┘
```

Service 通过 **Label Selector** 找到后端的 Pod，然后把流量负载均衡到这些 Pod 上。

---

## 四种 Service 类型

| 类型 | 作用 | 访问范围 | 使用场景 |
|------|------|---------|---------|
| **ClusterIP** | 集群内部访问 | 仅集群内 | 内部服务通信 |
| **NodePort** | 通过节点端口访问 | 集群外部 | 开发测试、简单暴露 |
| **LoadBalancer** | 云厂商负载均衡 | 互联网 | 生产环境对外服务 |
| **ExternalName** | DNS 别名 | 集群内 | 访问外部服务 |

用餐厅来比喻：
- **ClusterIP**：内部分机，只有员工能打
- **NodePort**：前台电话，外面的人也能打
- **LoadBalancer**：400 热线，专业客服接听
- **ExternalName**：外卖电话的快捷拨号

---

## 动手实验：ClusterIP Service

### 准备工作：创建后端 Pod

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f nginx-deployment.yaml

# 查看 Pod
kubectl get pods -l app=nginx -o wide
```

**实验输出**：
```
NAME                             READY   STATUS    RESTARTS   AGE   IP
nginx-backend-5d8f9b7c6d-2k4j8   1/1     Running   0          30s   10.244.1.5
nginx-backend-5d8f9b7c6d-8x2m3   1/1     Running   0          30s   10.244.2.8
nginx-backend-5d8f9b7c6d-p9n7k   1/1     Running   0          30s   10.244.3.2
```

三个 Pod，三个不同的 IP。

### 创建 ClusterIP Service

```yaml
# nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  type: ClusterIP          # 默认类型，可以省略
  selector:
    app: nginx             # 选择 label 为 app=nginx 的 Pod
  ports:
  - port: 80               # Service 端口
    targetPort: 80         # Pod 端口
    protocol: TCP
```

```bash
kubectl apply -f nginx-service.yaml

# 查看 Service
kubectl get svc nginx-svc
```

**实验输出**：
```
NAME        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
nginx-svc   ClusterIP   10.96.100.50   <none>        80/TCP    10s
```

Service 有了一个稳定的 ClusterIP：`10.96.100.50`

```bash
# 查看 Endpoints（Service 关联的 Pod）
kubectl get endpoints nginx-svc
```

**实验输出**：
```
NAME        ENDPOINTS                                      AGE
nginx-svc   10.244.1.5:80,10.244.2.8:80,10.244.3.2:80     30s
```

三个 Pod 的 IP 都在 Endpoints 里。

### 测试 Service

```bash
# 创建一个测试 Pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# 在测试 Pod 里访问 Service
wget -qO- http://nginx-svc
wget -qO- http://10.96.100.50
```

**实验输出**：
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

无论访问 Service 名称还是 ClusterIP，都能正常访问。

```bash
# 多次访问，观察负载均衡
for i in $(seq 1 10); do wget -qO- http://nginx-svc 2>&1 | head -1; done
```

请求会被分发到不同的 Pod。

---

## 动手实验：NodePort Service

NodePort 在每个节点上开放一个端口，外部可以通过 `节点IP:NodePort` 访问。

```yaml
# nginx-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80               # Service 端口（集群内访问）
    targetPort: 80         # Pod 端口
    nodePort: 30080        # 节点端口（30000-32767）
```

```bash
kubectl apply -f nginx-nodeport.yaml

# 查看 Service
kubectl get svc nginx-nodeport
```

**实验输出**：
```
NAME             TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx-nodeport   NodePort   10.96.200.100   <none>        80:30080/TCP   10s
```

```bash
# 获取节点 IP
kubectl get nodes -o wide

# 从集群外部访问（假设节点 IP 是 192.168.1.100）
curl http://192.168.1.100:30080
```

**端口关系**：
```
外部访问: 节点IP:30080 → Service:80 → Pod:80
集群内访问: nginx-nodeport:80 → Pod:80
```

---

## 动手实验：Headless Service

有时候你不需要负载均衡，而是想直接获取所有 Pod 的 IP。比如：
- StatefulSet 中的 Pod 需要稳定的网络标识
- 客户端想自己实现负载均衡

Headless Service 就是没有 ClusterIP 的 Service。

```yaml
# nginx-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None          # 关键：设置为 None
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f nginx-headless.yaml

# 查看 Service
kubectl get svc nginx-headless
```

**实验输出**：
```
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx-headless   ClusterIP   None         <none>        80/TCP    10s
```

ClusterIP 是 `None`。

```bash
# DNS 查询
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup nginx-headless
```

**实验输出**：
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      nginx-headless
Address 1: 10.244.1.5 nginx-backend-5d8f9b7c6d-2k4j8
Address 2: 10.244.2.8 nginx-backend-5d8f9b7c6d-8x2m3
Address 3: 10.244.3.2 nginx-backend-5d8f9b7c6d-p9n7k
```

DNS 返回了所有 Pod 的 IP，而不是一个 ClusterIP。

**对比**：
| 类型 | DNS 返回 | 用途 |
|------|---------|------|
| 普通 Service | ClusterIP | 负载均衡 |
| Headless Service | 所有 Pod IP | 直接访问 Pod |

---

## 动手实验：ExternalName Service

ExternalName 用于访问集群外部的服务，相当于 DNS 别名。

```yaml
# external-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com    # 外部服务的域名
```

```bash
kubectl apply -f external-service.yaml

# 在 Pod 里访问
kubectl run test-external --image=busybox --rm -it --restart=Never -- nslookup external-db
```

**实验输出**：
```
Name:      external-db
Address 1: <db.example.com 的 IP>
```

应用可以用 `external-db` 这个名字访问外部数据库，如果数据库地址变了，只需要修改 Service，不用改应用配置。

---

## Service 的 DNS 解析

K8s 为每个 Service 创建 DNS 记录：

```
<service-name>.<namespace>.svc.cluster.local
```

**示例**：
```bash
# 完整域名
nginx-svc.default.svc.cluster.local

# 同命名空间可以简写
nginx-svc

# 跨命名空间
nginx-svc.other-namespace
```

```bash
# 测试 DNS 解析
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup nginx-svc.default.svc.cluster.local
```

---

## Service 没有 Selector 的情况

有时候你想手动指定 Endpoints，而不是通过 Label 自动发现。

```yaml
# service-no-selector.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service    # 必须和 Service 同名
subsets:
- addresses:
  - ip: 192.168.1.100       # 外部服务器 IP
  - ip: 192.168.1.101
  ports:
  - port: 80
```

**使用场景**：
- 访问集群外部的服务
- 迁移过程中，部分服务还在集群外

---

## kube-proxy 的工作模式

Service 的流量转发由 kube-proxy 实现，有三种模式：

| 模式 | 原理 | 性能 | 特点 |
|------|------|------|------|
| **iptables** | iptables 规则 | 中等 | 默认模式，规则多时性能下降 |
| **ipvs** | IPVS 负载均衡 | 高 | 大规模集群推荐 |
| **userspace** | 用户空间代理 | 低 | 已废弃 |

```bash
# 查看 kube-proxy 模式
kubectl get configmap kube-proxy -n kube-system -o yaml | grep mode
```

---

## 最佳实践

### 1. 选择合适的 Service 类型

| 场景 | 推荐类型 |
|------|---------|
| 内部服务通信 | ClusterIP |
| 开发测试暴露 | NodePort |
| 生产环境对外 | LoadBalancer + Ingress |
| StatefulSet | Headless |
| 访问外部服务 | ExternalName |

### 2. 合理设置端口

```yaml
spec:
  ports:
  - name: http           # 多端口时必须命名
    port: 80             # Service 端口
    targetPort: 8080     # Pod 端口（可以不同）
  - name: https
    port: 443
    targetPort: 8443
```

### 3. 使用 sessionAffinity

如果需要会话保持（同一客户端的请求发到同一 Pod）：

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800    # 3 小时
```

---

## 清理实验环境

```bash
kubectl delete deployment nginx-backend
kubectl delete svc nginx-svc nginx-nodeport nginx-headless external-db external-service
rm -f nginx-deployment.yaml nginx-service.yaml nginx-nodeport.yaml nginx-headless.yaml external-service.yaml service-no-selector.yaml
```

---

## 核心要点总结

1. **Service 作用**：提供稳定的访问入口，负载均衡到后端 Pod

2. **四种类型**：
   - ClusterIP：集群内访问（默认）
   - NodePort：节点端口暴露
   - LoadBalancer：云厂商负载均衡
   - ExternalName：DNS 别名

3. **Headless Service**：clusterIP: None，返回所有 Pod IP

4. **DNS 格式**：`<service>.<namespace>.svc.cluster.local`

5. **Endpoints**：Service 关联的 Pod 列表，自动维护

记住这个比喻：**Service 是电话总机，Pod 是接线员，Endpoints 是通讯录**。

---

## 下一步

Service 解决了服务发现和负载均衡，但对于有状态应用（数据库、消息队列），Pod 需要稳定的网络标识和持久化存储。

下一篇我们学习 StatefulSet，它是专门为有状态应用设计的控制器。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[探针与健康检查](04-probes.md)  
**下一篇**：[StatefulSet 详解](06-statefulset.md)
