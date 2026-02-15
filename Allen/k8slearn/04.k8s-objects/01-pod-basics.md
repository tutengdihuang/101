# Pod 基础 - Kubernetes 的最小单元

> Pod 是 K8s 中最小的调度单元，理解 Pod 是理解 K8s 的第一步

## 什么是 Pod？

在 Docker 的世界里，容器是最小单元。但在 Kubernetes 的世界里，**Pod 才是最小的调度单元**。

为什么不直接用容器？因为有些应用需要多个容器紧密协作，它们需要：
- 共享网络（用 localhost 通信）
- 共享存储（访问同一个文件）
- 一起调度（在同一台机器上）

**Pod 就是一组紧密关联的容器的集合**。

### 生活化比喻

把 Pod 想象成一个**房间**：
- 一个房间可以住一个人（单容器 Pod）
- 一个房间也可以住一家人（多容器 Pod）
- 房间里的人共享空间、共享设施
- 房间是调度的最小单位（不能把一家人拆开住）

```
┌─────────────────────────────────────────┐
│                  Pod                    │
│  ┌─────────────┐    ┌─────────────┐    │
│  │  容器 A      │    │  容器 B      │    │
│  │  (主应用)    │    │  (日志收集)  │    │
│  └─────────────┘    └─────────────┘    │
│         │                  │           │
│         └────────┬─────────┘           │
│                  │                     │
│           共享网络和存储                 │
└─────────────────────────────────────────┘
```

---

## Pod 的核心特性

### 1. 共享网络

Pod 内的所有容器共享同一个网络命名空间：
- 共享 IP 地址
- 共享端口空间
- 可以用 `localhost` 互相通信

```
Pod IP: 10.244.1.5
├── 容器 A: 监听 80 端口
└── 容器 B: 监听 8080 端口

容器 B 访问容器 A: curl localhost:80
```

### 2. 共享存储

Pod 可以定义共享的 Volume，所有容器都可以挂载：

```
Pod
├── Volume: shared-data
├── 容器 A: 挂载到 /data
└── 容器 B: 挂载到 /data

容器 A 写入 /data/file.txt
容器 B 可以读取 /data/file.txt
```

### 3. 共同调度

Pod 内的所有容器一定在同一个节点上运行，一起创建、一起销毁。

---

## 动手实验：创建第一个 Pod

### 实验 1：使用命令行创建 Pod

```bash
# 创建一个 nginx Pod
kubectl run nginx-pod --image=nginx --port=80

# 查看 Pod 状态
kubectl get pods
```

**实验输出**：
```
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          30s
```

```bash
# 查看 Pod 详细信息
kubectl get pods -o wide
```

**实验输出**：
```
NAME        READY   STATUS    RESTARTS   AGE   IP           NODE
nginx-pod   1/1     Running   0          1m    10.244.1.5   node1
```

### 实验 2：使用 YAML 创建 Pod

创建 `simple-pod.yaml`：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-nginx
  labels:
    app: nginx
    env: demo
spec:
  containers:
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
```

**YAML 字段详解**：

| 字段 | 说明 |
|------|------|
| `apiVersion: v1` | API 版本，Pod 是核心资源，用 v1 |
| `kind: Pod` | 资源类型 |
| `metadata.name` | Pod 名称，在命名空间内唯一 |
| `metadata.labels` | 标签，用于选择和组织资源 |
| `spec.containers` | 容器列表 |
| `spec.containers[].name` | 容器名称 |
| `spec.containers[].image` | 镜像名称 |
| `spec.containers[].ports` | 暴露的端口 |

```bash
# 创建 Pod
kubectl apply -f simple-pod.yaml

# 查看 Pod
kubectl get pods simple-nginx
```

**实验输出**：
```
NAME           READY   STATUS    RESTARTS   AGE
simple-nginx   1/1     Running   0          10s
```

### 实验 3：查看 Pod 详情

```bash
# 查看 Pod 详细描述
kubectl describe pod simple-nginx
```

**实验输出**（关键部分）：
```
Name:         simple-nginx
Namespace:    default
Node:         node1/192.168.1.101
Labels:       app=nginx
              env=demo
IP:           10.244.1.6
Containers:
  nginx:
    Image:          nginx:1.21
    Port:           80/TCP
    State:          Running
      Started:      Thu, 15 Jan 2026 10:00:00 +0800
Events:
  Type    Reason     Age   Message
  ----    ------     ----  -------
  Normal  Scheduled  1m    Successfully assigned default/simple-nginx to node1
  Normal  Pulling    1m    Pulling image "nginx:1.21"
  Normal  Pulled     50s   Successfully pulled image "nginx:1.21"
  Normal  Created    50s   Created container nginx
  Normal  Started    50s   Started container nginx
```

### 实验 4：进入 Pod 执行命令

```bash
# 进入 Pod 执行命令
kubectl exec -it simple-nginx -- /bin/bash

# 在 Pod 内部执行
root@simple-nginx:/# curl localhost:80
root@simple-nginx:/# exit
```

**实验输出**：
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</html>
```

### 实验 5：查看 Pod 日志

```bash
# 查看 Pod 日志
kubectl logs simple-nginx

# 实时查看日志
kubectl logs -f simple-nginx
```

---

## 动手实验：多容器 Pod

有些场景需要多个容器协作，比如：
- 主应用 + 日志收集器
- 主应用 + 代理（Sidecar 模式）
- 主应用 + 配置同步器

### 实验 6：创建多容器 Pod

创建 `multi-container-pod.yaml`：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  # 主容器：nginx
  - name: nginx
    image: nginx:1.21
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # Sidecar 容器：日志收集
  - name: log-collector
    image: busybox
    command: ['sh', '-c', 'tail -f /var/log/nginx/access.log']
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # 共享存储
  volumes:
  - name: shared-logs
    emptyDir: {}
```

**架构说明**：
```
┌─────────────────────────────────────────────────┐
│              multi-container-pod                │
│  ┌─────────────────┐    ┌─────────────────┐    │
│  │     nginx       │    │  log-collector  │    │
│  │  写入日志到      │    │  读取日志并      │    │
│  │  /var/log/nginx │    │  输出到 stdout   │    │
│  └────────┬────────┘    └────────┬────────┘    │
│           │                      │             │
│           └──────────┬───────────┘             │
│                      │                         │
│              shared-logs (emptyDir)            │
└─────────────────────────────────────────────────┘
```

```bash
# 创建 Pod
kubectl apply -f multi-container-pod.yaml

# 查看 Pod 状态
kubectl get pods multi-container-pod
```

**实验输出**：
```
NAME                  READY   STATUS    RESTARTS   AGE
multi-container-pod   2/2     Running   0          30s
```

注意 `READY` 是 `2/2`，表示 Pod 内有 2 个容器都在运行。

### 实验 7：访问多容器 Pod 中的特定容器

```bash
# 进入 nginx 容器
kubectl exec -it multi-container-pod -c nginx -- /bin/bash

# 进入 log-collector 容器
kubectl exec -it multi-container-pod -c log-collector -- /bin/sh

# 查看 log-collector 的日志
kubectl logs multi-container-pod -c log-collector
```

### 实验 8：验证容器间通信

```bash
# 进入 nginx 容器，访问自己
kubectl exec -it multi-container-pod -c nginx -- curl localhost:80

# 在 log-collector 中也可以访问 nginx（共享网络）
kubectl exec -it multi-container-pod -c log-collector -- wget -qO- localhost:80
```

---

## Pod 的生命周期

Pod 有以下几种状态：

| 状态 | 说明 |
|------|------|
| **Pending** | Pod 已创建，但容器还没运行（可能在拉取镜像） |
| **Running** | Pod 已绑定到节点，所有容器都已创建，至少一个在运行 |
| **Succeeded** | 所有容器都成功终止，不会重启 |
| **Failed** | 所有容器都已终止，至少一个是失败退出 |
| **Unknown** | 无法获取 Pod 状态（通常是节点通信问题） |

```
创建 Pod
    │
    ▼
┌─────────┐
│ Pending │ ← 等待调度、拉取镜像
└────┬────┘
     │
     ▼
┌─────────┐
│ Running │ ← 容器运行中
└────┬────┘
     │
     ├──────────────┐
     ▼              ▼
┌───────────┐  ┌────────┐
│ Succeeded │  │ Failed │
└───────────┘  └────────┘
```

---

## 常用 kubectl 命令

| 命令 | 说明 |
|------|------|
| `kubectl get pods` | 列出所有 Pod |
| `kubectl get pods -o wide` | 显示更多信息（IP、节点等） |
| `kubectl get pods --show-labels` | 显示标签 |
| `kubectl describe pod <name>` | 查看 Pod 详情 |
| `kubectl logs <pod>` | 查看日志 |
| `kubectl logs <pod> -c <container>` | 查看多容器 Pod 中特定容器的日志 |
| `kubectl exec -it <pod> -- <cmd>` | 在 Pod 中执行命令 |
| `kubectl delete pod <name>` | 删除 Pod |

---

## 清理实验环境

```bash
# 删除创建的 Pod
kubectl delete pod nginx-pod simple-nginx multi-container-pod
```

---

## 核心要点总结

1. **Pod 是什么**：K8s 最小调度单元，一组紧密关联的容器
2. **共享特性**：共享网络（localhost 通信）、共享存储、共同调度
3. **单容器 vs 多容器**：
   - 单容器 Pod：最常见，一个 Pod 一个容器
   - 多容器 Pod：Sidecar 模式，容器间紧密协作
4. **生命周期**：Pending → Running → Succeeded/Failed
5. **关键命令**：`kubectl get/describe/logs/exec`

记住这个比喻：**Pod 就像一个房间，可以住一个人或一家人，房间里的人共享空间和设施**。

---

## 思考题

1. 为什么 K8s 不直接调度容器，而是调度 Pod？
2. 什么场景适合使用多容器 Pod？什么场景应该用多个单容器 Pod？
3. Pod 被删除后，里面的数据会怎样？（提示：emptyDir vs PVC）

---

## 下一步

Pod 是基础，但直接管理 Pod 有很多问题：
- Pod 挂了不会自动重启
- 无法方便地扩缩容
- 无法实现滚动更新

下一篇我们学习 Deployment，它是管理 Pod 的"物业公司"。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[README](README.md)  
**下一篇**：[Deployment 详解](02-deployment.md)
