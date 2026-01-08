# 添加监控目标

> 🎯 如何让 Prometheus 监控你的应用

## 一、前置条件

1. 应用已暴露 `/metrics` 端点
2. 应用有对应的 Service
3. kube-prometheus-stack 已安装

---

## 二、快速开始

### 2.1 检查应用是否暴露指标

```bash
# 端口转发到应用
kubectl port-forward -n <namespace> svc/<service-name> 9090:9090

# 访问指标端点
curl http://localhost:9090/metrics
```

### 2.2 创建 ServiceMonitor

```yaml
# my-app-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-servicemonitor
  namespace: monitoring              # 放在 monitoring 命名空间
  labels:
    release: prometheus              # ⚠️ 必须有这个标签！
spec:
  namespaceSelector:
    matchNames:
      - default                      # 应用所在的命名空间
  selector:
    matchLabels:
      app: my-app                    # 匹配 Service 的标签
  endpoints:
    - port: metrics                  # Service 中定义的端口名
      interval: 30s                  # 抓取间隔
      path: /metrics                 # 指标路径
```

### 2.3 应用配置

```bash
kubectl apply -f my-app-servicemonitor.yaml
```

### 2.4 验证

```bash
# 检查 ServiceMonitor 是否创建
kubectl get servicemonitor -n monitoring

# 检查 Prometheus Targets（等待 1-2 分钟）
# 访问 http://182.42.82.135:30909/targets
```

---

## 三、完整示例

### 3.1 示例应用

假设你有一个 Go 应用，暴露了 `/metrics` 端点：

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-go-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-go-app
  template:
    metadata:
      labels:
        app: my-go-app
    spec:
      containers:
      - name: app
        image: my-go-app:latest
        ports:
        - name: http
          containerPort: 8080
        - name: metrics           # 指标端口
          containerPort: 9090
```

### 3.2 创建 Service

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-go-app
  namespace: default
  labels:
    app: my-go-app                # 这个标签用于 ServiceMonitor 匹配
spec:
  selector:
    app: my-go-app
  ports:
  - name: http
    port: 8080
    targetPort: http
  - name: metrics                 # 指标端口
    port: 9090
    targetPort: metrics
```

### 3.3 创建 ServiceMonitor

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-go-app-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus           # ⚠️ 必须！
    app: my-go-app                # 可选，便于管理
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: my-go-app              # 匹配 Service 的标签
  endpoints:
    - port: metrics               # 匹配 Service 的端口名
      interval: 30s
      path: /metrics
```

### 3.4 应用所有配置

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f servicemonitor.yaml
```

---

## 四、监控 Tekton

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-pipelines
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - tekton-pipelines
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/part-of: tekton-pipelines
  endpoints:
    - port: http-metrics
      interval: 30s
      path: /metrics
```

---

## 五、监控 ArgoCD

```yaml
# ArgoCD Application Controller
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-application-controller
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  endpoints:
    - port: "8082"
      interval: 30s
      path: /metrics
---
# ArgoCD Repo Server
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

---

## 六、使用 PodMonitor

如果应用没有 Service，可以使用 PodMonitor：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: my-job-podmonitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: my-batch-job
  podMetricsEndpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

---

## 七、常见问题排查

### Q1: Target 没有出现

**检查清单**：

```bash
# 1. 检查 ServiceMonitor 是否有正确的标签
kubectl get servicemonitor -n monitoring my-app-servicemonitor -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 2. 检查 Service 是否存在且标签匹配
kubectl get svc -n default -l app=my-app

# 3. 检查 Service 端口名是否匹配
kubectl get svc -n default my-app -o yaml | grep -A10 ports

# 4. 检查 Prometheus Operator 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator --tail=50
```

### Q2: Target 显示 DOWN

```bash
# 1. 检查 Pod 是否运行
kubectl get pods -n default -l app=my-app

# 2. 检查指标端点是否可访问
kubectl port-forward -n default svc/my-app 9090:9090
curl http://localhost:9090/metrics

# 3. 检查网络策略
kubectl get networkpolicy -n default
```

### Q3: 指标抓取超时

```yaml
# 增加超时时间
endpoints:
  - port: metrics
    interval: 30s
    scrapeTimeout: 25s    # 必须小于 interval
```

---

## 八、最佳实践

### 8.1 命名规范

```yaml
# ServiceMonitor 命名：<app-name>-servicemonitor
name: my-app-servicemonitor
```

### 8.2 标签规范

```yaml
labels:
  release: prometheus     # 必须
  app: my-app             # 可选，便于管理
  team: platform          # 可选，便于分类
```

### 8.3 抓取间隔建议

| 指标类型 | 建议间隔 |
|---------|---------|
| 业务指标 | 15s-30s |
| 基础设施 | 30s-60s |
| 批处理任务 | 60s-300s |

---

## 九、验证命令汇总

```bash
# 查看所有 ServiceMonitor
kubectl get servicemonitor -n monitoring

# 查看 ServiceMonitor 详情
kubectl describe servicemonitor my-app-servicemonitor -n monitoring

# 查看 Prometheus 配置
kubectl get prometheus -n monitoring -o yaml

# 查看 Prometheus Targets
# 访问 http://182.42.82.135:30909/targets

# 测试指标查询
# 访问 http://182.42.82.135:30909/graph
# 输入指标名查询
```

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
