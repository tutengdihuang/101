# StatefulSet 详解 - 有状态应用的守护者

> 不是所有应用都能"随便杀"，有些需要被温柔以待

## Deployment 的局限

Deployment 很强大，但它有一个假设：**所有 Pod 都是一样的，可以随意替换**。

这对无状态应用（Web 服务器、API 服务）没问题，但对有状态应用就不行了：

| 应用类型 | 特点 | 能用 Deployment 吗？ |
|---------|------|---------------------|
| Nginx | 无状态，随便换 | ✅ 可以 |
| MySQL 主从 | 主从有区别，数据要持久化 | ❌ 不行 |
| Redis 集群 | 每个节点有固定角色 | ❌ 不行 |
| Kafka | 每个 Broker 有唯一 ID | ❌ 不行 |
| Zookeeper | 节点需要稳定的网络标识 | ❌ 不行 |

有状态应用需要：
1. **稳定的网络标识**：Pod 名称和 DNS 不变
2. **稳定的存储**：Pod 重建后数据还在
3. **有序的部署和扩缩容**：按顺序启动和停止

**StatefulSet 就是为此而生**。

---

## StatefulSet vs Deployment

| 特性 | Deployment | StatefulSet |
|------|-----------|-------------|
| Pod 名称 | 随机后缀（nginx-5d8f9b7c6d-x2k4j） | 有序编号（nginx-0, nginx-1） |
| 网络标识 | 不稳定 | 稳定（通过 Headless Service） |
| 存储 | 共享或无 | 每个 Pod 独立的 PVC |
| 启动顺序 | 并行 | 有序（0 → 1 → 2） |
| 删除顺序 | 并行 | 逆序（2 → 1 → 0） |
| 适用场景 | 无状态应用 | 有状态应用 |

用学校来比喻：
- **Deployment**：学生可以随便换座位，谁坐哪都一样
- **StatefulSet**：每个学生有固定学号和座位，还有自己的储物柜

---

## StatefulSet 的三大保证

### 1. 稳定的网络标识

每个 Pod 有固定的名称和 DNS：

```
Pod 名称: <statefulset-name>-<ordinal>
DNS: <pod-name>.<service-name>.<namespace>.svc.cluster.local
```

**示例**：
```
Pod: nginx-ss-0, nginx-ss-1, nginx-ss-2
DNS: nginx-ss-0.nginx-ss.default.svc.cluster.local
     nginx-ss-1.nginx-ss.default.svc.cluster.local
     nginx-ss-2.nginx-ss.default.svc.cluster.local
```

即使 Pod 被删除重建，名称和 DNS 保持不变。

### 2. 稳定的存储

每个 Pod 有自己独立的 PVC（PersistentVolumeClaim）：

```
Pod nginx-ss-0 → PVC www-nginx-ss-0 → PV
Pod nginx-ss-1 → PVC www-nginx-ss-1 → PV
Pod nginx-ss-2 → PVC www-nginx-ss-2 → PV
```

Pod 被删除后，PVC 不会被删除，数据保留。新 Pod 会自动绑定原来的 PVC。

### 3. 有序的部署和扩缩容

- **创建**：按顺序创建（0 → 1 → 2），前一个 Ready 后才创建下一个
- **删除**：逆序删除（2 → 1 → 0）
- **更新**：逆序更新（2 → 1 → 0）

这对于主从架构很重要：先启动主节点，再启动从节点。

---

## 动手实验：创建 StatefulSet

### 前置条件：Headless Service

StatefulSet 必须配合 Headless Service 使用，用于提供稳定的 DNS。

```yaml
# nginx-statefulset.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ss
  labels:
    app: nginx-ss
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None          # Headless Service
  selector:
    app: nginx-ss
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-ss
spec:
  serviceName: "nginx-ss"  # 必须指定 Headless Service 名称
  replicas: 3
  selector:
    matchLabels:
      app: nginx-ss
  template:
    metadata:
      labels:
        app: nginx-ss
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          name: web
```

```bash
kubectl apply -f nginx-statefulset.yaml

# 观察 Pod 创建顺序
kubectl get pods -l app=nginx-ss -w
```

**实验输出**：
```
NAME         READY   STATUS    RESTARTS   AGE
nginx-ss-0   0/1     Pending   0          0s
nginx-ss-0   0/1     ContainerCreating   0          0s
nginx-ss-0   1/1     Running   0          5s
nginx-ss-1   0/1     Pending   0          0s      # 0 Ready 后才创建 1
nginx-ss-1   0/1     ContainerCreating   0          0s
nginx-ss-1   1/1     Running   0          5s
nginx-ss-2   0/1     Pending   0          0s      # 1 Ready 后才创建 2
nginx-ss-2   0/1     ContainerCreating   0          0s
nginx-ss-2   1/1     Running   0          5s
```

注意：Pod 是按顺序创建的，不是并行的。

### 验证稳定的网络标识

```bash
# 查看 Pod 名称
kubectl get pods -l app=nginx-ss
```

**实验输出**：
```
NAME         READY   STATUS    RESTARTS   AGE
nginx-ss-0   1/1     Running   0          60s
nginx-ss-1   1/1     Running   0          55s
nginx-ss-2   1/1     Running   0          50s
```

Pod 名称是有序的：nginx-ss-0, nginx-ss-1, nginx-ss-2

```bash
# 测试 DNS 解析
kubectl run test-dns --image=busybox --rm -it --restart=Never -- sh

# 在测试 Pod 里执行
nslookup nginx-ss-0.nginx-ss
nslookup nginx-ss-1.nginx-ss
nslookup nginx-ss-2.nginx-ss
```

**实验输出**：
```
Name:      nginx-ss-0.nginx-ss
Address 1: 10.244.1.10 nginx-ss-0.nginx-ss.default.svc.cluster.local

Name:      nginx-ss-1.nginx-ss
Address 1: 10.244.2.15 nginx-ss-1.nginx-ss.default.svc.cluster.local

Name:      nginx-ss-2.nginx-ss
Address 1: 10.244.3.20 nginx-ss-2.nginx-ss.default.svc.cluster.local
```

每个 Pod 都有独立的 DNS 记录。

### 验证 Pod 重建后网络标识不变

```bash
# 删除一个 Pod
kubectl delete pod nginx-ss-1

# 观察重建
kubectl get pods -l app=nginx-ss -w
```

**实验输出**：
```
NAME         READY   STATUS    RESTARTS   AGE
nginx-ss-0   1/1     Running   0          5m
nginx-ss-1   1/1     Terminating   0       5m
nginx-ss-2   1/1     Running   0          5m
nginx-ss-1   0/1     Pending   0          0s      # 新 Pod，同样的名字
nginx-ss-1   0/1     ContainerCreating   0          0s
nginx-ss-1   1/1     Running   0          5s
```

新 Pod 的名字还是 `nginx-ss-1`，DNS 也不变。

---

## 动手实验：StatefulSet + PVC

真正的有状态应用需要持久化存储。

```yaml
# statefulset-with-pvc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-pvc
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx-pvc
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-pvc
spec:
  serviceName: "nginx-pvc"
  replicas: 2
  selector:
    matchLabels:
      app: nginx-pvc
  template:
    metadata:
      labels:
        app: nginx-pvc
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:           # PVC 模板
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

```bash
kubectl apply -f statefulset-with-pvc.yaml

# 查看 PVC
kubectl get pvc
```

**实验输出**：
```
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES
www-nginx-pvc-0   Bound    pvc-a1b2c3d4-e5f6-7890-abcd-ef1234567890   1Gi        RWO
www-nginx-pvc-1   Bound    pvc-b2c3d4e5-f6a7-8901-bcde-f12345678901   1Gi        RWO
```

每个 Pod 有自己独立的 PVC。

### 验证数据持久化

```bash
# 在 Pod 0 写入数据
kubectl exec nginx-pvc-0 -- sh -c 'echo "Hello from Pod 0" > /usr/share/nginx/html/index.html'

# 在 Pod 1 写入数据
kubectl exec nginx-pvc-1 -- sh -c 'echo "Hello from Pod 1" > /usr/share/nginx/html/index.html'

# 验证数据
kubectl exec nginx-pvc-0 -- cat /usr/share/nginx/html/index.html
kubectl exec nginx-pvc-1 -- cat /usr/share/nginx/html/index.html
```

**实验输出**：
```
Hello from Pod 0
Hello from Pod 1
```

```bash
# 删除 Pod 0
kubectl delete pod nginx-pvc-0

# 等待重建后验证数据还在
kubectl exec nginx-pvc-0 -- cat /usr/share/nginx/html/index.html
```

**实验输出**：
```
Hello from Pod 0
```

数据还在！因为 PVC 没有被删除，新 Pod 绑定了原来的 PVC。

---

## 扩缩容实验

### 扩容

```bash
# 扩容到 4 个副本
kubectl scale statefulset nginx-ss --replicas=4

# 观察
kubectl get pods -l app=nginx-ss -w
```

**实验输出**：
```
nginx-ss-3   0/1     Pending   0          0s      # 按顺序创建 3
nginx-ss-3   0/1     ContainerCreating   0          0s
nginx-ss-3   1/1     Running   0          5s
```

### 缩容

```bash
# 缩容到 2 个副本
kubectl scale statefulset nginx-ss --replicas=2

# 观察
kubectl get pods -l app=nginx-ss -w
```

**实验输出**：
```
nginx-ss-3   1/1     Terminating   0          60s     # 先删除 3
nginx-ss-2   1/1     Terminating   0          65s     # 再删除 2
```

缩容是逆序的：3 → 2。

**注意**：缩容时 PVC 不会被删除，数据保留。如果再扩容回来，新 Pod 会绑定原来的 PVC。

---

## 更新策略

StatefulSet 支持两种更新策略：

### 1. RollingUpdate（默认）

逆序滚动更新：从最大编号开始，一个一个更新。

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0    # 只更新编号 >= partition 的 Pod
```

**partition 的妙用**：金丝雀发布

```bash
# 只更新 nginx-ss-2（编号 >= 2）
kubectl patch statefulset nginx-ss -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

# 更新镜像
kubectl set image statefulset nginx-ss nginx=nginx:1.19

# 只有 nginx-ss-2 会更新，0 和 1 保持不变
```

验证没问题后，逐步降低 partition：

```bash
kubectl patch statefulset nginx-ss -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'
# nginx-ss-1 更新

kubectl patch statefulset nginx-ss -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
# nginx-ss-0 更新
```

### 2. OnDelete

手动删除 Pod 后才更新。

```yaml
spec:
  updateStrategy:
    type: OnDelete
```

---

## 实际应用场景

### MySQL 主从

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:5.7
        command:
        - bash
        - "-c"
        - |
          # 根据 Pod 序号决定是主还是从
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          if [[ $ordinal -eq 0 ]]; then
            echo "I am master"
            # 主节点配置
          else
            echo "I am slave"
            # 从节点配置
          fi
      containers:
      - name: mysql
        image: mysql:5.7
        # ...
```

### Redis 集群

```yaml
# redis-ss-0 → redis-ss-0.redis.default.svc.cluster.local
# redis-ss-1 → redis-ss-1.redis.default.svc.cluster.local
# ...
# 每个节点有稳定的 DNS，可以用于集群配置
```

---

## 清理实验环境

```bash
kubectl delete statefulset nginx-ss nginx-pvc
kubectl delete svc nginx-ss nginx-pvc
kubectl delete pvc --all    # 注意：这会删除所有 PVC
rm -f nginx-statefulset.yaml statefulset-with-pvc.yaml
```

---

## 核心要点总结

1. **StatefulSet 三大保证**：
   - 稳定的网络标识（Pod 名称 + DNS）
   - 稳定的存储（独立的 PVC）
   - 有序的部署和扩缩容

2. **必须配合 Headless Service**：提供稳定的 DNS

3. **Pod 命名规则**：`<statefulset-name>-<ordinal>`

4. **DNS 格式**：`<pod-name>.<service-name>.<namespace>.svc.cluster.local`

5. **PVC 不会自动删除**：缩容或删除 StatefulSet 后，PVC 保留

6. **更新策略**：
   - RollingUpdate：逆序滚动更新，支持 partition
   - OnDelete：手动删除后更新

记住这个比喻：**StatefulSet 是学校，每个学生（Pod）有固定学号（名称）、座位（DNS）和储物柜（PVC）**。

---

## 系列总结

恭喜你完成了 K8s 核心对象的学习！让我们回顾一下：

| 对象 | 作用 | 一句话总结 |
|------|------|-----------|
| Pod | 最小调度单位 | 容器的"宿舍" |
| Deployment | 无状态应用管理 | Pod 的"班主任" |
| ConfigMap | 配置管理 | 公告栏 |
| Secret | 敏感信息管理 | 保险箱 |
| Probe | 健康检查 | 体检医生 |
| Service | 服务发现和负载均衡 | 电话总机 |
| StatefulSet | 有状态应用管理 | 学校（有学号、座位、储物柜） |

这些对象组合起来，就能部署和管理各种应用了。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[Service 与网络](05-service.md)  
**返回目录**：[K8s 核心对象](README.md)
