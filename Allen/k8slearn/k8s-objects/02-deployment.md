# Deployment 详解 - 无状态应用的管家

> 让 Pod 自动重启、轻松扩缩容、平滑滚动更新

## 为什么需要 Deployment？

直接管理 Pod 有很多问题：

| 问题 | 直接管理 Pod | 使用 Deployment |
|------|-------------|-----------------|
| Pod 挂了 | 不会自动重启 | 自动创建新 Pod |
| 扩缩容 | 手动创建/删除 Pod | 改个数字就行 |
| 更新版本 | 手动删旧建新 | 自动滚动更新 |
| 回滚 | 没有历史记录 | 一键回滚 |

**Deployment 就是 Pod 的"物业公司"**，负责：
- 确保指定数量的 Pod 在运行
- Pod 挂了自动补充
- 支持滚动更新和回滚

---

## Deployment 的工作原理

Deployment 不直接管理 Pod，而是通过 ReplicaSet：

```
┌─────────────────────────────────────────────────────────┐
│                     Deployment                          │
│  - 管理 ReplicaSet                                      │
│  - 控制更新策略                                          │
│  - 记录版本历史                                          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     ReplicaSet                          │
│  - 确保指定数量的 Pod 运行                               │
│  - Pod 挂了自动补充                                      │
└─────────────────────────────────────────────────────────┘
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
        ┌───────┐     ┌───────┐     ┌───────┐
        │ Pod 1 │     │ Pod 2 │     │ Pod 3 │
        └───────┘     └───────┘     └───────┘
```

---

## 动手实验：创建 Deployment

### 实验 1：使用命令行创建 Deployment

```bash
# 创建 nginx Deployment
kubectl create deployment nginx-deploy --image=nginx:1.21 --replicas=3

# 查看 Deployment
kubectl get deployments
```

**实验输出**：
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deploy   3/3     3            3           30s
```

```bash
# 查看 Pod
kubectl get pods -l app=nginx-deploy
```

**实验输出**：
```
NAME                            READY   STATUS    RESTARTS   AGE
nginx-deploy-6799fc88d8-abc12   1/1     Running   0          30s
nginx-deploy-6799fc88d8-def34   1/1     Running   0          30s
nginx-deploy-6799fc88d8-ghi56   1/1     Running   0          30s
```

### 实验 2：使用 YAML 创建 Deployment

创建 `nginx-deployment.yaml`：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3                    # 副本数量
  selector:
    matchLabels:
      app: nginx                 # 选择器，匹配 Pod 的标签
  template:                      # Pod 模板
    metadata:
      labels:
        app: nginx               # Pod 的标签，必须匹配 selector
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

**YAML 字段详解**：

| 字段 | 说明 |
|------|------|
| `spec.replicas` | 期望的 Pod 副本数 |
| `spec.selector` | 用于选择 Pod 的标签选择器 |
| `spec.template` | Pod 模板，定义 Pod 的规格 |
| `spec.template.metadata.labels` | Pod 的标签，必须匹配 selector |
| `spec.template.spec` | Pod 的规格（容器、存储等） |

```bash
# 创建 Deployment
kubectl apply -f nginx-deployment.yaml

# 查看 Deployment 详情
kubectl describe deployment nginx-deployment
```

---

## 动手实验：扩缩容

### 实验 3：扩容

```bash
# 扩容到 5 个副本
kubectl scale deployment nginx-deployment --replicas=5

# 查看 Pod
kubectl get pods -l app=nginx
```

**实验输出**：
```
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6799fc88d8-abc12   1/1     Running   0          5m
nginx-deployment-6799fc88d8-def34   1/1     Running   0          5m
nginx-deployment-6799fc88d8-ghi56   1/1     Running   0          5m
nginx-deployment-6799fc88d8-jkl78   1/1     Running   0          10s
nginx-deployment-6799fc88d8-mno90   1/1     Running   0          10s
```

### 实验 4：缩容

```bash
# 缩容到 2 个副本
kubectl scale deployment nginx-deployment --replicas=2

# 查看 Pod（会看到一些 Pod 正在 Terminating）
kubectl get pods -l app=nginx -w
```

**实验输出**：
```
NAME                                READY   STATUS        RESTARTS   AGE
nginx-deployment-6799fc88d8-abc12   1/1     Running       0          6m
nginx-deployment-6799fc88d8-def34   1/1     Running       0          6m
nginx-deployment-6799fc88d8-ghi56   1/1     Terminating   0          6m
nginx-deployment-6799fc88d8-jkl78   1/1     Terminating   0          1m
nginx-deployment-6799fc88d8-mno90   1/1     Terminating   0          1m
```

---

## 动手实验：自愈能力

### 实验 5：删除 Pod，观察自动恢复

```bash
# 获取一个 Pod 名称
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
echo "删除 Pod: $POD_NAME"

# 删除 Pod
kubectl delete pod $POD_NAME

# 观察 Pod 变化
kubectl get pods -l app=nginx -w
```

**实验输出**：
```
NAME                                READY   STATUS        RESTARTS   AGE
nginx-deployment-6799fc88d8-abc12   1/1     Terminating   0          10m
nginx-deployment-6799fc88d8-def34   1/1     Running       0          10m
nginx-deployment-6799fc88d8-xyz99   0/1     Pending       0          0s
nginx-deployment-6799fc88d8-xyz99   0/1     ContainerCreating   0   0s
nginx-deployment-6799fc88d8-xyz99   1/1     Running       0          5s
```

Pod 被删除后，Deployment 自动创建了一个新的 Pod！这就是自愈能力。

---

## 动手实验：滚动更新

### 实验 6：更新镜像版本

```bash
# 当前版本
kubectl get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
# 输出: nginx:1.21

# 更新到新版本
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# 观察滚动更新过程
kubectl rollout status deployment/nginx-deployment
```

**实验输出**：
```
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
deployment "nginx-deployment" successfully rolled out
```

### 实验 7：观察滚动更新细节

```bash
# 查看 ReplicaSet
kubectl get rs -l app=nginx
```

**实验输出**：
```
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-6799fc88d8   0         0         0       15m    # 旧版本
nginx-deployment-7d9b8c6f5d   2         2         2       1m     # 新版本
```

滚动更新的过程：
1. 创建新的 ReplicaSet
2. 逐步增加新 ReplicaSet 的副本数
3. 逐步减少旧 ReplicaSet 的副本数
4. 最终旧 ReplicaSet 副本数为 0

```
更新前:
旧 RS: ████████ (2 个 Pod)
新 RS: (0 个 Pod)

更新中:
旧 RS: ████ (1 个 Pod)
新 RS: ████ (1 个 Pod)

更新后:
旧 RS: (0 个 Pod)
新 RS: ████████ (2 个 Pod)
```

---

## 动手实验：回滚

### 实验 8：查看更新历史

```bash
# 查看更新历史
kubectl rollout history deployment/nginx-deployment
```

**实验输出**：
```
deployment.apps/nginx-deployment
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### 实验 9：回滚到上一个版本

```bash
# 回滚到上一个版本
kubectl rollout undo deployment/nginx-deployment

# 查看当前版本
kubectl get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
# 输出: nginx:1.21
```

### 实验 10：回滚到指定版本

```bash
# 回滚到指定版本
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# 查看历史
kubectl rollout history deployment/nginx-deployment
```

---

## 更新策略详解

Deployment 支持两种更新策略：

### 1. RollingUpdate（默认）

滚动更新，逐步替换旧 Pod：

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # 更新时最多可以多出 25% 的 Pod
      maxUnavailable: 25%  # 更新时最多可以有 25% 的 Pod 不可用
```

| 参数 | 说明 | 示例（10 个副本） |
|------|------|------------------|
| `maxSurge` | 最多可以多出多少 Pod | 25% = 最多 13 个 Pod |
| `maxUnavailable` | 最多可以有多少 Pod 不可用 | 25% = 最少 8 个 Pod 可用 |

### 2. Recreate

先删除所有旧 Pod，再创建新 Pod：

```yaml
spec:
  strategy:
    type: Recreate
```

**适用场景**：应用不支持多版本同时运行（比如数据库迁移）

---

## 实战：部署 Envoy 代理

Envoy 是一个高性能代理，常用于服务网格。让我们用 Deployment + ConfigMap 部署它。

### 实验 11：创建 Envoy 配置

```bash
# 创建 envoy 配置文件
cat > envoy-config.yaml << 'EOF'
admin:
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }

static_resources:
  listeners:
    - name: listener_0
      address:
        socket_address: { address: 0.0.0.0, port_value: 10000 }
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: local_service
                      domains: ["*"]
                      routes:
                        - match: { prefix: "/" }
                          route: { cluster: nginx_cluster }
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
    - name: nginx_cluster
      connect_timeout: 0.25s
      type: LOGICAL_DNS
      lb_policy: ROUND_ROBIN
      load_assignment:
        cluster_name: nginx_cluster
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: nginx-service
                      port_value: 80
EOF

# 创建 ConfigMap
kubectl create configmap envoy-config --from-file=envoy.yaml=envoy-config.yaml
```

### 实验 12：创建 Envoy Deployment

```yaml
# envoy-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
  labels:
    app: envoy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: envoy
  template:
    metadata:
      labels:
        app: envoy
    spec:
      containers:
      - name: envoy
        image: envoyproxy/envoy:v1.28-latest
        ports:
        - containerPort: 10000
        volumeMounts:
        - name: envoy-config
          mountPath: /etc/envoy
          readOnly: true
      volumes:
      - name: envoy-config
        configMap:
          name: envoy-config
```

```bash
# 创建 Deployment
kubectl apply -f envoy-deployment.yaml

# 暴露服务
kubectl expose deployment envoy --port=10000 --type=NodePort

# 查看服务
kubectl get svc envoy
```

---

## 清理实验环境

```bash
kubectl delete deployment nginx-deploy nginx-deployment envoy
kubectl delete configmap envoy-config
kubectl delete svc envoy
rm -f nginx-deployment.yaml envoy-deployment.yaml envoy-config.yaml
```

---

## 核心要点总结

1. **Deployment 是什么**：管理无状态应用的控制器，通过 ReplicaSet 管理 Pod
2. **核心功能**：
   - 副本管理：确保指定数量的 Pod 运行
   - 自愈能力：Pod 挂了自动补充
   - 滚动更新：平滑升级，不中断服务
   - 版本回滚：一键回滚到历史版本
3. **更新策略**：
   - RollingUpdate：滚动更新（默认）
   - Recreate：先删后建
4. **关键命令**：
   - `kubectl scale`：扩缩容
   - `kubectl set image`：更新镜像
   - `kubectl rollout status/history/undo`：管理更新

记住这个比喻：**Deployment 是 Pod 的物业公司，负责维护、扩容、升级**。

---

## 下一步

Deployment 管理了 Pod 的生命周期，但应用的配置怎么管理？

下一篇我们学习 ConfigMap 和 Secret，它们是 K8s 的配置管理方案。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[Pod 基础](01-pod-basics.md)  
**下一篇**：[ConfigMap 与 Secret](03-configmap-secret.md)
