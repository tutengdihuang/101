# CI/CD 监控指南：让流水线透明可控

> 🎯 **一句话精华**：CI/CD 监控 = Pipeline 执行状态 + GitOps 同步状态 + 构建性能指标——让每次发布都心中有数！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Pipeline 执行失败了，怎么第一时间知道？
ArgoCD 应用 OutOfSync 了，怎么自动告警？
构建时间越来越长，怎么发现瓶颈？
CI/CD 监控帮你回答这些问题！
```

**适合谁学**：负责 CI/CD 系统运维的 DevOps 工程师
**不适合谁**：只使用 CI/CD 不关心监控的开发人员

---

## 二、CI/CD 监控架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      CI/CD 监控全景图                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    CI 持续集成                           │    │
│  │                                                          │    │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐          │    │
│  │  │ Tekton   │    │ Jenkins  │    │ GitLab   │          │    │
│  │  │ Pipeline │    │ Pipeline │    │ CI       │          │    │
│  │  └────┬─────┘    └────┬─────┘    └────┬─────┘          │    │
│  │       │               │               │                 │    │
│  │       └───────────────┼───────────────┘                 │    │
│  │                       │                                 │    │
│  │                       ▼                                 │    │
│  │              ┌─────────────────┐                        │    │
│  │              │  /metrics 端点  │                        │    │
│  │              └────────┬────────┘                        │    │
│  └───────────────────────┼──────────────────────────────────┘    │
│                          │                                       │
│  ┌───────────────────────┼──────────────────────────────────┐    │
│  │                    CD 持续部署                           │    │
│  │                       │                                  │    │
│  │  ┌──────────┐    ┌────┴─────┐    ┌──────────┐          │    │
│  │  │ ArgoCD   │    │ Flux     │    │ Spinnaker│          │    │
│  │  │ GitOps   │    │ GitOps   │    │          │          │    │
│  │  └────┬─────┘    └────┬─────┘    └────┬─────┘          │    │
│  │       │               │               │                 │    │
│  │       └───────────────┼───────────────┘                 │    │
│  │                       │                                 │    │
│  │                       ▼                                 │    │
│  │              ┌─────────────────┐                        │    │
│  │              │  /metrics 端点  │                        │    │
│  │              └────────┬────────┘                        │    │
│  └───────────────────────┼──────────────────────────────────┘    │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Prometheus                            │    │
│  │              (抓取 CI/CD 指标)                           │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│              ┌────────────┼────────────┐                        │
│              ▼            ▼            ▼                        │
│        ┌──────────┐ ┌──────────┐ ┌──────────┐                  │
│        │ Grafana  │ │AlertMgr  │ │ PromQL   │                  │
│        │ Dashboard│ │ 告警     │ │ 查询     │                  │
│        └──────────┘ └──────────┘ └──────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、Tekton 监控

### 3.1 Tekton 指标概览

| 指标类型 | 指标前缀 | 说明 |
|---------|---------|------|
| PipelineRun | `tekton_pipelinerun_` | Pipeline 执行指标 |
| TaskRun | `tekton_taskrun_` | Task 执行指标 |
| Controller | `tekton_pipelines_controller_` | 控制器指标 |

### 3.2 配置 Tekton ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-pipelines
  namespace: monitoring
  labels:
    release: prometheus              # ⚠️ 必须有这个标签！
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

### 3.3 常用 Tekton PromQL 查询

```promql
# Pipeline 执行次数（按状态分组）
sum by(status) (tekton_pipelinerun_count)

# Pipeline 成功率
sum(tekton_pipelinerun_count{status="success"}) 
/ sum(tekton_pipelinerun_count) * 100

# Pipeline 执行时长（P95）
histogram_quantile(0.95, sum by(le) (rate(tekton_pipelinerun_duration_seconds_bucket[1h])))

# Pipeline 执行时长（平均）
rate(tekton_pipelinerun_duration_seconds_sum[1h]) 
/ rate(tekton_pipelinerun_duration_seconds_count[1h])

# 失败的 Pipeline
tekton_pipelinerun_count{status="failed"} > 0

# 正在运行的 Pipeline
tekton_pipelinerun_count{status="running"}

# Task 执行次数（按状态分组）
sum by(status) (tekton_taskrun_count)

# Task 成功率
sum(tekton_taskrun_count{status="success"}) 
/ sum(tekton_taskrun_count) * 100

# 最慢的 Task（按名称）
topk(10, avg by(task) (tekton_taskrun_duration_seconds_sum / tekton_taskrun_duration_seconds_count))
```

### 3.4 Tekton 告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tekton-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: tekton.rules
      rules:
        # Pipeline 执行失败
        - alert: TektonPipelineRunFailed
          expr: |
            increase(tekton_pipelinerun_count{status="failed"}[5m]) > 0
          for: 1m
          labels:
            severity: critical
            component: tekton
          annotations:
            summary: "Tekton Pipeline 执行失败"
            description: "Pipeline {{ $labels.pipeline }} 在过去 5 分钟内执行失败"
        
        # Pipeline 执行时间过长
        - alert: TektonPipelineRunTooLong
          expr: |
            tekton_pipelinerun_duration_seconds_sum{status="running"} 
            / tekton_pipelinerun_duration_seconds_count{status="running"} > 1800
          for: 5m
          labels:
            severity: warning
            component: tekton
          annotations:
            summary: "Tekton Pipeline 执行时间过长"
            description: "Pipeline {{ $labels.pipeline }} 平均执行时间超过 30 分钟"
        
        # Pipeline 成功率下降
        - alert: TektonPipelineSuccessRateLow
          expr: |
            sum(tekton_pipelinerun_count{status="success"}) 
            / sum(tekton_pipelinerun_count) * 100 < 80
          for: 10m
          labels:
            severity: warning
            component: tekton
          annotations:
            summary: "Tekton Pipeline 成功率下降"
            description: "Pipeline 成功率低于 80%，当前值: {{ $value | printf \"%.1f\" }}%"
        
        # Tekton Controller 不健康
        - alert: TektonControllerDown
          expr: |
            up{job="tekton-pipelines-controller"} == 0
          for: 5m
          labels:
            severity: critical
            component: tekton
          annotations:
            summary: "Tekton Controller 不可用"
            description: "Tekton Controller 已经不可用超过 5 分钟"
```

---

## 四、ArgoCD 监控

### 4.1 ArgoCD 指标概览

| 指标类型 | 指标前缀 | 说明 |
|---------|---------|------|
| 应用状态 | `argocd_app_` | 应用同步和健康状态 |
| 同步操作 | `argocd_app_sync_` | 同步操作指标 |
| API Server | `argocd_api_server_` | API 服务器指标 |
| Repo Server | `argocd_repo_server_` | 仓库服务器指标 |

### 4.2 配置 ArgoCD ServiceMonitor

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
    - port: metrics
      interval: 30s
      path: /metrics
---
# ArgoCD Server
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
    - port: metrics
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

### 4.3 常用 ArgoCD PromQL 查询

```promql
# 应用同步状态分布
sum by(sync_status) (argocd_app_info)

# 应用健康状态分布
sum by(health_status) (argocd_app_info)

# 未同步的应用
argocd_app_info{sync_status="OutOfSync"} == 1

# 不健康的应用
argocd_app_info{health_status!="Healthy"} == 1

# 应用同步次数（1小时内）
increase(argocd_app_sync_total[1h])

# 同步失败次数
increase(argocd_app_sync_total{phase="Failed"}[1h])

# 同步成功率
sum(argocd_app_sync_total{phase="Succeeded"}) 
/ sum(argocd_app_sync_total) * 100

# 应用数量
count(argocd_app_info)

# 按项目统计应用数量
count by(project) (argocd_app_info)

# 按目标集群统计应用数量
count by(dest_server) (argocd_app_info)

# Repo Server Git 请求延迟（P95）
histogram_quantile(0.95, sum by(le) (rate(argocd_git_request_duration_seconds_bucket[5m])))

# API Server 请求延迟（P95）
histogram_quantile(0.95, sum by(le) (rate(argocd_api_server_request_duration_seconds_bucket[5m])))
```

### 4.4 ArgoCD 告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: argocd.rules
      rules:
        # 应用未同步
        - alert: ArgoCDAppOutOfSync
          expr: |
            argocd_app_info{sync_status="OutOfSync"} == 1
          for: 10m
          labels:
            severity: warning
            component: argocd
          annotations:
            summary: "ArgoCD 应用未同步"
            description: "应用 {{ $labels.name }} 处于 OutOfSync 状态超过 10 分钟"
        
        # 应用健康异常
        - alert: ArgoCDAppDegraded
          expr: |
            argocd_app_info{health_status="Degraded"} == 1
          for: 5m
          labels:
            severity: critical
            component: argocd
          annotations:
            summary: "ArgoCD 应用健康异常"
            description: "应用 {{ $labels.name }} 健康状态为 Degraded"
        
        # 应用健康状态未知
        - alert: ArgoCDAppHealthUnknown
          expr: |
            argocd_app_info{health_status="Unknown"} == 1
          for: 15m
          labels:
            severity: warning
            component: argocd
          annotations:
            summary: "ArgoCD 应用健康状态未知"
            description: "应用 {{ $labels.name }} 健康状态为 Unknown 超过 15 分钟"
        
        # 同步失败
        - alert: ArgoCDAppSyncFailed
          expr: |
            increase(argocd_app_sync_total{phase="Failed"}[10m]) > 0
          for: 1m
          labels:
            severity: critical
            component: argocd
          annotations:
            summary: "ArgoCD 应用同步失败"
            description: "应用 {{ $labels.name }} 在过去 10 分钟内同步失败"
        
        # ArgoCD 组件不健康
        - alert: ArgoCDComponentDown
          expr: |
            up{job=~"argocd.*"} == 0
          for: 5m
          labels:
            severity: critical
            component: argocd
          annotations:
            summary: "ArgoCD 组件不可用"
            description: "ArgoCD 组件 {{ $labels.job }} 已经不可用超过 5 分钟"
        
        # Git 请求延迟过高
        - alert: ArgoCDGitRequestLatencyHigh
          expr: |
            histogram_quantile(0.95, sum by(le) (rate(argocd_git_request_duration_seconds_bucket[5m]))) > 10
          for: 5m
          labels:
            severity: warning
            component: argocd
          annotations:
            summary: "ArgoCD Git 请求延迟过高"
            description: "Git 请求 P95 延迟超过 10 秒"
```

---

## 五、CI/CD Dashboard 设计

### 5.1 Tekton Dashboard 面板

**Pipeline 概览**：
```promql
# 总执行次数
sum(tekton_pipelinerun_count)

# 成功次数
sum(tekton_pipelinerun_count{status="success"})

# 失败次数
sum(tekton_pipelinerun_count{status="failed"})

# 成功率
sum(tekton_pipelinerun_count{status="success"}) / sum(tekton_pipelinerun_count) * 100
```

**执行时长趋势**：
```promql
# 平均执行时长
avg(tekton_pipelinerun_duration_seconds_sum / tekton_pipelinerun_duration_seconds_count)

# P95 执行时长
histogram_quantile(0.95, sum by(le) (rate(tekton_pipelinerun_duration_seconds_bucket[1h])))
```

**Pipeline 状态分布（饼图）**：
```promql
sum by(status) (tekton_pipelinerun_count)
```

### 5.2 ArgoCD Dashboard 面板

**应用概览**：
```promql
# 应用总数
count(argocd_app_info)

# 同步的应用数
count(argocd_app_info{sync_status="Synced"})

# 未同步的应用数
count(argocd_app_info{sync_status="OutOfSync"})

# 健康的应用数
count(argocd_app_info{health_status="Healthy"})
```

**同步状态分布（饼图）**：
```promql
sum by(sync_status) (argocd_app_info)
```

**健康状态分布（饼图）**：
```promql
sum by(health_status) (argocd_app_info)
```

**同步操作趋势**：
```promql
# 同步次数
increase(argocd_app_sync_total[1h])

# 按结果分组
sum by(phase) (increase(argocd_app_sync_total[1h]))
```

### 5.3 推荐 Grafana Dashboard

| Dashboard | ID | 说明 |
|-----------|-----|------|
| Tekton Dashboard | 自定义 | Tekton Pipeline 监控 |
| ArgoCD Dashboard | 14584 | ArgoCD 官方推荐 |

---

## 六、CI/CD 监控最佳实践

### 6.1 关键指标（黄金指标）

| 指标类型 | CI (Tekton) | CD (ArgoCD) |
|---------|-------------|-------------|
| 成功率 | Pipeline 成功率 | 同步成功率 |
| 延迟 | Pipeline 执行时长 | 同步延迟 |
| 吞吐量 | Pipeline 执行次数 | 同步次数 |
| 错误 | Pipeline 失败次数 | 同步失败次数 |

### 6.2 告警策略

| 场景 | 告警级别 | for 时间 | 说明 |
|------|---------|---------|------|
| Pipeline 失败 | critical | 1m | 立即通知 |
| Pipeline 超时 | warning | 5m | 关注但不紧急 |
| 应用 OutOfSync | warning | 10m | 给自动同步时间 |
| 应用 Degraded | critical | 5m | 影响服务 |
| 组件 Down | critical | 5m | 系统故障 |

### 6.3 Dashboard 设计原则

1. **概览优先**：首屏显示关键指标（成功率、失败数）
2. **趋势可见**：展示时间序列，发现趋势
3. **问题定位**：提供下钻能力，快速定位问题
4. **告警联动**：Dashboard 与告警规则对应

---

## 七、常见问题排查

### Q1: Tekton 指标没有数据

```bash
# 1. 检查 Tekton Controller 是否暴露指标
kubectl port-forward -n tekton-pipelines svc/tekton-pipelines-controller 9090:9090
curl http://localhost:9090/metrics

# 2. 检查 ServiceMonitor 是否正确
kubectl get servicemonitor -n monitoring tekton-pipelines -o yaml

# 3. 检查 Prometheus Targets
# 访问 http://<prometheus-ip>:<port>/targets
```

### Q2: ArgoCD 指标没有数据

```bash
# 1. 检查 ArgoCD 组件是否暴露指标
kubectl port-forward -n argocd svc/argocd-application-controller 8082:8082
curl http://localhost:8082/metrics

# 2. 检查 Service 标签是否匹配
kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-application-controller

# 3. 检查 ServiceMonitor selector
kubectl get servicemonitor -n monitoring argocd-application-controller -o yaml
```

### Q3: 告警不触发

```bash
# 1. 在 Prometheus UI 测试表达式
# 访问 http://<prometheus-ip>:<port>/graph

# 2. 检查 PrometheusRule 是否加载
curl http://<prometheus-ip>:<port>/api/v1/rules | grep argocd

# 3. 检查告警状态
# 访问 http://<prometheus-ip>:<port>/alerts
```

---

## 八、金句收藏

```
"CI/CD 监控三要素：成功率、执行时长、失败告警"

"Pipeline 失败要秒级告警，OutOfSync 可以等 10 分钟"

"没有监控的 CI/CD = 盲人开车"

"Dashboard 是给人看的，告警是给机器发的"

"成功率下降 = 代码质量问题 or 环境问题"
```

---

## 九、学习检查清单

- [ ] 理解 CI/CD 监控的核心指标
- [ ] 会配置 Tekton ServiceMonitor
- [ ] 会配置 ArgoCD ServiceMonitor
- [ ] 会写 Tekton 相关的 PromQL 查询
- [ ] 会写 ArgoCD 相关的 PromQL 查询
- [ ] 会配置 CI/CD 告警规则
- [ ] 能排查 CI/CD 监控常见问题

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：Tekton 0.50+, ArgoCD 2.x

---

> 📝 **系列导航**：
> - 上一篇：[PromQL 查询手册](09-promql-cookbook.md)
> - 下一篇：[故障排查指南](guides/troubleshooting.md)
