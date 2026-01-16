# 探针与健康检查 - K8s 的"体检医生"

> 你的应用真的健康吗？别让 K8s 蒙在鼓里

## 一个真实的故事

某天凌晨 3 点，运维小王被电话吵醒。用户反馈：网站打不开了。

小王登录服务器一看：Pod 状态是 Running，看起来一切正常。但实际上，应用早就因为数据库连接池耗尽而"假死"了——进程还在，但已经无法处理请求。

K8s 看到进程还活着，就认为一切正常，继续把流量往这个"僵尸" Pod 上发...

**这就是为什么我们需要探针**：让 K8s 真正了解应用的健康状态，而不是只看进程是否存在。

---

## 三种探针，各司其职

K8s 提供了三种探针，就像医院的三种检查：

| 探针类型 | 作用 | 生活比喻 | 失败后果 |
|---------|------|---------|---------|
| **Liveness Probe** | 检查应用是否存活 | 心跳检测 | 重启容器 |
| **Readiness Probe** | 检查应用是否准备好接收流量 | 上岗前体检 | 从 Service 移除 |
| **Startup Probe** | 检查应用是否启动完成 | 新员工入职培训 | 延迟其他探针 |

用餐厅来比喻：
- **Liveness**：厨师还活着吗？（死了就换一个）
- **Readiness**：厨师准备好做菜了吗？（没准备好就不接单）
- **Startup**：新厨师培训完了吗？（培训期间不考核）

---

## 三种检查方式

探针支持三种检查方式：

### 1. HTTP GET

向容器发送 HTTP 请求，返回 200-399 表示成功。

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome
  initialDelaySeconds: 3
  periodSeconds: 3
```

**适用场景**：Web 应用、API 服务

### 2. TCP Socket

尝试建立 TCP 连接，连接成功表示健康。

```yaml
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 10
```

**适用场景**：数据库、Redis 等不提供 HTTP 接口的服务

### 3. Exec 命令

在容器内执行命令，返回 0 表示成功。

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

**适用场景**：需要自定义检查逻辑的场景

---

## 动手实验：Liveness Probe

### 实验 1：HTTP 探针

创建一个会"生病"的应用：启动后 10 秒内健康，之后返回 500 错误。

```yaml
# liveness-http.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/liveness
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 3    # 启动后等 3 秒再检查
      periodSeconds: 3          # 每 3 秒检查一次
      failureThreshold: 3       # 连续失败 3 次才认为不健康
```

```bash
# 创建 Pod
kubectl apply -f liveness-http.yaml

# 观察 Pod 状态（会看到 RESTARTS 不断增加）
kubectl get pod liveness-http -w
```

**实验输出**：
```
NAME            READY   STATUS    RESTARTS   AGE
liveness-http   1/1     Running   0          10s
liveness-http   1/1     Running   1          30s
liveness-http   1/1     Running   2          60s
```

```bash
# 查看事件，了解发生了什么
kubectl describe pod liveness-http
```

**关键事件**：
```
Events:
  Warning  Unhealthy  Container liveness: Liveness probe failed: HTTP probe failed with statuscode: 500
  Normal   Killing    Container liveness: Container liveness failed liveness probe, will be restarted
```

### 实验 2：Exec 探针

创建一个通过文件存在与否来判断健康的 Pod：

```yaml
# liveness-exec.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox
    args:
    - /bin/sh
    - -c
    # 启动后创建健康文件，30秒后删除
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

```bash
kubectl apply -f liveness-exec.yaml

# 观察 Pod（30秒后会重启）
kubectl get pod liveness-exec -w
```

**实验输出**：
```
NAME            READY   STATUS    RESTARTS   AGE
liveness-exec   1/1     Running   0          5s
liveness-exec   1/1     Running   0          30s
liveness-exec   1/1     Running   1          45s
```

---

## 动手实验：Readiness Probe

Readiness 探针决定 Pod 是否接收流量。这在以下场景特别有用：
- 应用启动时需要加载大量数据
- 应用需要等待依赖服务就绪
- 应用正在进行热更新

### 实验：手动控制 Pod 就绪状态

```yaml
# readiness-manual.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readiness-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: readiness-demo
  template:
    metadata:
      labels:
        app: readiness-demo
    spec:
      containers:
      - name: centos
        image: centos
        command:
        - tail
        - -f
        - /dev/null
        readinessProbe:
          exec:
            command:
            - cat
            - /tmp/healthy
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: readiness-svc
spec:
  selector:
    app: readiness-demo
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f readiness-manual.yaml

# 查看 Pod 状态（注意 READY 列）
kubectl get pod -l app=readiness-demo
```

**实验输出**：
```
NAME                              READY   STATUS    RESTARTS   AGE
readiness-demo-5d8f9b7c6d-x2k4j   0/1     Running   0          30s
```

注意：`READY` 是 `0/1`，说明 Pod 还没准备好。

```bash
# 查看 Endpoints（应该是空的）
kubectl get endpoints readiness-svc
```

**实验输出**：
```
NAME            ENDPOINTS   AGE
readiness-svc   <none>      30s
```

没有 Endpoints！这意味着 Service 不会把流量发到这个 Pod。

```bash
# 手动让 Pod 变成就绪状态
kubectl exec -it $(kubectl get pod -l app=readiness-demo -o jsonpath='{.items[0].metadata.name}') -- touch /tmp/healthy

# 等待几秒后再查看
kubectl get pod -l app=readiness-demo
```

**实验输出**：
```
NAME                              READY   STATUS    RESTARTS   AGE
readiness-demo-5d8f9b7c6d-x2k4j   1/1     Running   0          60s
```

现在 `READY` 变成 `1/1` 了！

```bash
# 再查看 Endpoints
kubectl get endpoints readiness-svc
```

**实验输出**：
```
NAME            ENDPOINTS        AGE
readiness-svc   10.244.1.15:80   60s
```

Pod 的 IP 出现在 Endpoints 中，可以接收流量了。

```bash
# 模拟应用"生病"，删除健康文件
kubectl exec -it $(kubectl get pod -l app=readiness-demo -o jsonpath='{.items[0].metadata.name}') -- rm /tmp/healthy

# 等待几秒后查看
kubectl get pod -l app=readiness-demo
kubectl get endpoints readiness-svc
```

Pod 又变成 `0/1`，从 Endpoints 中移除了。

**关键区别**：
- Liveness 失败 → 重启容器
- Readiness 失败 → 从 Service 移除，但不重启

---

## 动手实验：Startup Probe

对于启动慢的应用（比如 Java 应用），如果用 Liveness 探针，可能应用还没启动完就被杀掉了。

Startup Probe 专门解决这个问题：在启动期间，只有 Startup Probe 生效，其他探针暂停。

```yaml
# startup-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:
  - name: app
    image: busybox
    args:
    - /bin/sh
    - -c
    # 模拟慢启动：60秒后才创建健康文件
    - sleep 60; touch /tmp/healthy; sleep 600
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      failureThreshold: 30      # 最多允许失败 30 次
      periodSeconds: 10         # 每 10 秒检查一次
      # 总共允许 30 * 10 = 300 秒的启动时间
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      periodSeconds: 10
```

```bash
kubectl apply -f startup-probe.yaml

# 观察 Pod 状态
kubectl get pod startup-demo -w
```

**实验输出**：
```
NAME           READY   STATUS    RESTARTS   AGE
startup-demo   0/1     Running   0          10s
startup-demo   0/1     Running   0          30s
startup-demo   0/1     Running   0          60s
startup-demo   1/1     Running   0          70s
```

60 秒后，Startup Probe 成功，Pod 变成 Ready，然后 Liveness Probe 开始工作。

---

## 探针参数详解

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5    # 容器启动后等待多久开始探测
  periodSeconds: 10         # 探测间隔
  timeoutSeconds: 1         # 探测超时时间
  successThreshold: 1       # 连续成功多少次才算成功（Liveness/Startup 只能是 1）
  failureThreshold: 3       # 连续失败多少次才算失败
```

**参数选择建议**：

| 参数 | 建议值 | 说明 |
|------|-------|------|
| initialDelaySeconds | 根据应用启动时间 | Java 应用可能需要 30-60 秒 |
| periodSeconds | 10-30 秒 | 太频繁会增加负载 |
| timeoutSeconds | 1-5 秒 | 根据接口响应时间 |
| failureThreshold | 3 | 避免偶发失败导致重启 |

---

## 最佳实践

### 1. 健康检查接口设计

```go
// 好的健康检查接口
func healthz(w http.ResponseWriter, r *http.Request) {
    // 检查关键依赖
    if err := db.Ping(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        return
    }
    if err := redis.Ping(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
}
```

### 2. Liveness vs Readiness 选择

| 场景 | 使用探针 | 原因 |
|------|---------|------|
| 应用死锁 | Liveness | 需要重启恢复 |
| 数据库连接断开 | Readiness | 重启也没用，等待恢复 |
| 应用启动中 | Readiness | 启动完成前不接收流量 |
| 内存泄漏 | Liveness | 重启可以临时解决 |

### 3. 避免常见错误

```yaml
# ❌ 错误：initialDelaySeconds 太短
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 1    # Java 应用 1 秒肯定启动不完

# ✅ 正确：给足启动时间，或使用 Startup Probe
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 60   # 或者使用 Startup Probe
```

```yaml
# ❌ 错误：Liveness 检查外部依赖
livenessProbe:
  httpGet:
    path: /check-database    # 数据库挂了，应用也被重启，雪崩！

# ✅ 正确：Liveness 只检查应用自身，外部依赖用 Readiness
livenessProbe:
  httpGet:
    path: /healthz           # 只检查应用自身
readinessProbe:
  httpGet:
    path: /ready             # 检查外部依赖
```

---

## 清理实验环境

```bash
kubectl delete pod liveness-http liveness-exec startup-demo
kubectl delete deployment readiness-demo
kubectl delete service readiness-svc
rm -f liveness-http.yaml liveness-exec.yaml readiness-manual.yaml startup-probe.yaml
```

---

## 核心要点总结

1. **三种探针**：
   - Liveness：应用是否存活，失败则重启
   - Readiness：应用是否就绪，失败则移除流量
   - Startup：应用是否启动完成，保护慢启动应用

2. **三种检查方式**：
   - HTTP GET：Web 应用
   - TCP Socket：数据库等
   - Exec：自定义检查

3. **关键参数**：
   - initialDelaySeconds：启动延迟
   - periodSeconds：检查间隔
   - failureThreshold：失败阈值

4. **最佳实践**：
   - Liveness 只检查应用自身
   - Readiness 检查外部依赖
   - 慢启动应用使用 Startup Probe

记住这个比喻：**Liveness 是心跳监测，Readiness 是上岗体检，Startup 是入职培训**。

---

## 下一步

探针让 K8s 了解应用健康状态，但 Pod 之间如何通信？如何暴露服务给外部访问？

下一篇我们学习 Service，它是 K8s 的服务发现和负载均衡机制。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[ConfigMap 与 Secret](03-configmap-secret.md)  
**下一篇**：[Service 与网络](05-service.md)
