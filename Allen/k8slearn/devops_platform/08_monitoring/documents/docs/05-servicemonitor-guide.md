# ServiceMonitor 配置指南

> 🎯 告诉 Prometheus "去哪里采集指标"的配置文件

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Prometheus 不知道要监控谁
ServiceMonitor 就是"通讯录"，告诉 Prometheus：
- 去哪个命名空间找
- 找哪个 Service
- 从哪个端口抓取
- 多久抓一次
```

**一句话精华**：
```
ServiceMonitor = Prometheus 的"监控目标配置文件"
```

**适合谁学**：需要添加新监控目标的运维/开发人员
**不适合谁**：只使用现有监控的用户

---

## 二、核心框架（知识骨架）

**核心观点**：
```
传统 Prometheus：手动在配置文件里写 scrape_configs
Prometheus Operator：用 ServiceMonitor CRD 自动发现
```

**关键概念速查表**：

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| ServiceMonitor | 监控目标配置 | 通讯录 | 告诉 Prometheus 去哪里抓取 |
| PodMonitor | Pod 级别监控配置 | 直接联系人 | 不通过 Service，直接找 Pod |
| namespaceSelector | 命名空间选择器 | 城市筛选 | 只监控某些命名空间 |
| selector | Service 选择器 | 姓名筛选 | 只监控某些 Service |
| endpoints | 端点配置 | 联系方式 | 端口、路径、间隔 |

**ServiceMonitor 工作流程**：

```
┌─────────────────────────────────────────────────────────────────┐
│                  ServiceMonitor 工作流程                         │
│                                                                  │
│  1. 创建 ServiceMonitor                                          │
│     ↓                                                            │
│  2. Prometheus Operator 发现 ServiceMonitor                      │
│     ↓                                                            │
│  3. Operator 更新 Prometheus 配置                                │
│     ↓                                                            │
│  4. Prometheus 根据配置抓取目标                                   │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ServiceMonitor│───▶│  Prometheus  │───▶│   Target     │       │
│  │   (配置)     │    │  Operator    │    │  (Exporter)  │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、ServiceMonitor 详解

### 3.1 完整结构

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-servicemonitor      # ServiceMonitor 名称
  namespace: monitoring            # 建议放在 monitoring 命名空间
  labels:
    release: prometheus            # ⚠️ 必须！Prometheus 通过这个标签发现
spec:
  # 选择要监控的命名空间
  namespaceSelector:
    matchNames:
      - default
      - production
    # 或者监控所有命名空间
    # any: true
  
  # 选择要监控的 Service（通过标签）
  selector:
    matchLabels:
      app: my-app
    # 或者使用表达式
    # matchExpressions:
    #   - key: app
    #     operator: In
    #     values: [my-app, my-app-v2]
  
  # 端点配置（可以有多个）
  endpoints:
    - port: metrics              # Service 中定义的端口名称
      interval: 30s              # 抓取间隔
      path: /metrics             # 指标路径
      scheme: http               # 协议（http/https）
      scrapeTimeout: 10s         # 抓取超时
      # 可选：添加额外标签
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_node_name]
          targetLabel: node
```

### 3.2 关键字段详解

#### namespaceSelector（命名空间选择器）

```yaml
# 方式1：指定命名空间列表
namespaceSelector:
  matchNames:
    - default
    - production
    - staging

# 方式2：监控所有命名空间
namespaceSelector:
  any: true

# 方式3：只监控 ServiceMonitor 所在的命名空间（默认行为）
# 不写 namespaceSelector 即可
```

#### selector（Service 选择器）

```yaml
# 方式1：精确匹配标签
selector:
  matchLabels:
    app: my-app
    version: v1

# 方式2：表达式匹配
selector:
  matchExpressions:
    - key: app
      operator: In
      values: [my-app, my-app-v2]
    - key: environment
      operator: NotIn
      values: [test]
```

#### endpoints（端点配置）

```yaml
endpoints:
  - port: metrics              # 端口名称（对应 Service 中的 port.name）
    interval: 30s              # 抓取间隔（建议 15s-60s）
    path: /metrics             # 指标路径（默认 /metrics）
    scheme: http               # 协议（http/https）
    scrapeTimeout: 10s         # 超时时间（必须小于 interval）
    
    # 可选：Bearer Token 认证
    bearerTokenSecret:
      name: my-secret
      key: token
    
    # 可选：TLS 配置
    tlsConfig:
      insecureSkipVerify: true
    
    # 可选：Basic Auth
    basicAuth:
      username:
        name: my-secret
        key: username
      password:
        name: my-secret
        key: password
```

---

## 四、PodMonitor 详解

### 4.1 什么时候用 PodMonitor？

| 场景 | 使用 ServiceMonitor | 使用 PodMonitor |
|------|-------------------|-----------------|
| 有 Service 的应用 | ✅ 推荐 | ❌ |
| 无 Service 的 Pod | ❌ | ✅ 推荐 |
| DaemonSet | ✅ 可以 | ✅ 可以 |
| Job/CronJob | ❌ | ✅ 推荐 |

### 4.2 PodMonitor 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: my-job-podmonitor
  namespace: monitoring
  labels:
    release: prometheus          # ⚠️ 必须！
spec:
  namespaceSelector:
    matchNames:
      - default
  
  # 选择 Pod（通过标签）
  selector:
    matchLabels:
      app: my-batch-job
  
  # Pod 端口配置
  podMetricsEndpoints:
    - port: metrics              # Pod 中定义的端口名称
      interval: 30s
      path: /metrics
```

---

## 五、实战示例

### 5.1 监控自定义应用

**场景**：你有一个 Go 应用，暴露了 `/metrics` 端点

**Step 1: 确保应用有 Service**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-go-app
  namespace: default
  labels:
    app: my-go-app              # 这个标签很重要！
spec:
  selector:
    app: my-go-app
  ports:
    - name: http
      port: 8080
    - name: metrics             # 指标端口
      port: 9090
```

**Step 2: 创建 ServiceMonitor**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-go-app-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus         # ⚠️ 必须！
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: my-go-app            # 匹配 Service 的标签
  endpoints:
    - port: metrics             # 匹配 Service 的端口名
      interval: 30s
      path: /metrics
```

**Step 3: 验证**

```bash
# 检查 ServiceMonitor 是否创建
kubectl get servicemonitor -n monitoring

# 检查 Prometheus Targets
# 访问 http://182.42.82.135:30909/targets
# 应该能看到新的 target
```

### 5.2 监控 Tekton

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

### 5.3 监控 ArgoCD

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
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
```

---

## 六、常见问题排查

### Q1: ServiceMonitor 创建了但 Target 没出现

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
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

### Q2: Target 显示 DOWN

**检查清单**：

```bash
# 1. 检查 Pod 是否运行
kubectl get pods -n default -l app=my-app

# 2. 检查指标端点是否可访问
kubectl port-forward -n default svc/my-app 9090:9090
curl http://localhost:9090/metrics

# 3. 检查网络策略是否阻止
kubectl get networkpolicy -n default
```

### Q3: 指标抓取超时

**解决方案**：

```yaml
endpoints:
  - port: metrics
    interval: 30s
    scrapeTimeout: 25s    # 增加超时时间（必须小于 interval）
```

---

## 七、最佳实践

### 7.1 命名规范

```yaml
# ServiceMonitor 命名：<app-name>-servicemonitor
name: my-app-servicemonitor

# 或者：<app-name>-metrics
name: my-app-metrics
```

### 7.2 标签规范

```yaml
labels:
  release: prometheus           # 必须
  app: my-app                   # 可选，便于管理
  team: platform                # 可选，便于分类
```

### 7.3 抓取间隔建议

| 指标类型 | 建议间隔 | 说明 |
|---------|---------|------|
| 业务指标 | 15s-30s | 需要及时发现问题 |
| 基础设施 | 30s-60s | 变化相对缓慢 |
| 批处理任务 | 60s-300s | 不需要高频采集 |

### 7.4 资源标签传递

```yaml
endpoints:
  - port: metrics
    relabelings:
      # 添加 Pod 所在节点
      - sourceLabels: [__meta_kubernetes_pod_node_name]
        targetLabel: node
      # 添加 Pod 名称
      - sourceLabels: [__meta_kubernetes_pod_name]
        targetLabel: pod
```

---

## 八、金句收藏

```
"ServiceMonitor 是 Prometheus 的 GPS——没有它，Prometheus 就是个路痴"

"写 ServiceMonitor 最重要的一件事：别忘了 release: prometheus 标签！"
```

---

## 九、延伸资源

- [Prometheus Operator 官方文档](https://prometheus-operator.dev/docs/user-guides/getting-started/)
- [ServiceMonitor API 参考](https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.ServiceMonitor)
- 操作指南：[添加监控目标](../guides/add-servicemonitor.md)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- 适用环境：Prometheus Operator / kube-prometheus-stack
