# Design Document

## Introduction

本设计文档描述 AlertManager 告警系统的架构设计，包括组件部署、告警规则配置、通知渠道设置和 Grafana 集成。

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │   Tekton    │    │   ArgoCD    │    │   Node Exporter     │ │
│  │  Metrics    │    │  Metrics    │    │     Metrics         │ │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬──────────┘ │
│         │                  │                      │             │
│         └──────────────────┼──────────────────────┘             │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Prometheus                               ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │              PrometheusRules                         │   ││
│  │  │  - cicd-alerting-rules (Tekton/ArgoCD)              │   ││
│  │  │  - infrastructure-alerting-rules (Node/Pod)         │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  └──────────────────────────┬──────────────────────────────────┘│
│                             │ alerts                            │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   AlertManager                              ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │              Route Configuration                     │   ││
│  │  │  - critical-receiver (severity=critical)            │   ││
│  │  │  - warning-receiver (severity=warning)              │   ││
│  │  │  - cicd-receiver (Tekton/ArgoCD alerts)             │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │              Inhibit Rules                           │   ││
│  │  │  - critical inhibits warning (same alert)           │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  └──────────────────────────┬──────────────────────────────────┘│
│                             │ notifications                     │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Receivers                                 ││
│  │  - Webhook (default)                                        ││
│  │  - Email (optional, requires SMTP)                          ││
│  │  - 钉钉/企业微信 (optional)                                  ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Grafana                                  ││
│  │  - AlertManager DataSource                                  ││
│  │  - Alert Status Panel                                       ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. AlertManager Deployment

**部署方式**: 通过 kube-prometheus-stack Helm Chart 部署

**配置位置**: `Allen/k8slearn/devops_platform/08_monitoring/install/values.yaml`

**关键配置**:
```yaml
alertmanager:
  enabled: true
  service:
    type: NodePort
    nodePort: 30903
  alertmanagerSpec:
    image:
      registry: swr.cn-north-4.myhuaweicloud.com
      repository: ddn-k8s/quay.io/prometheus/alertmanager
      tag: v0.27.0
    retention: 120h
    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi
        cpu: 100m
```

### 2. Alert Rules Design

#### 2.1 CI/CD Alert Rules

**文件**: `Allen/k8slearn/devops_platform/08_monitoring/install/cicd-alerting-rules.yaml`

| 告警名称 | 触发条件 | 严重级别 | 持续时间 |
|---------|---------|---------|---------|
| TektonPipelineRunFailed | PipelineRun 失败 | critical | 1m |
| TektonPipelineRunTooLong | PipelineRun 运行 > 30min | warning | 30m |
| TektonTooManyRunningPipelines | 并发 > 10 | warning | 5m |
| ArgoCDAppOutOfSync | 应用未同步 | warning | 10m |
| ArgoCDAppDegraded | 应用健康异常 | critical | 5m |
| ArgoCDAppMissing | 应用资源缺失 | critical | 5m |
| ArgoCDSyncFailed | 同步失败 | critical | 1m |

#### 2.2 Infrastructure Alert Rules

**文件**: `Allen/k8slearn/devops_platform/08_monitoring/install/infrastructure-alerting-rules.yaml`

| 告警名称 | 触发条件 | 严重级别 | 持续时间 |
|---------|---------|---------|---------|
| NodeHighCPUUsage | CPU > 80% | warning | 5m |
| NodeCriticalCPUUsage | CPU > 95% | critical | 5m |
| NodeHighMemoryUsage | Memory > 85% | warning | 5m |
| NodeHighDiskUsage | Disk > 80% | warning | 5m |
| NodeCriticalDiskUsage | Disk > 90% | critical | 5m |
| PodCrashLoopBackOff | CrashLoopBackOff | critical | 5m |
| PodFrequentRestart | 重启 > 5次/10min | warning | 1m |
| PodPendingTooLong | Pending > 15min | warning | 15m |
| PodOOMKilled | OOM 终止 | critical | 1m |

### 3. Routing Configuration

**路由策略**:
```yaml
route:
  group_by: ['alertname', 'namespace', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-receiver'
      group_wait: 10s
      repeat_interval: 1h
    - match:
        severity: warning
      receiver: 'warning-receiver'
      repeat_interval: 4h
    - match_re:
        alertname: ^(Tekton|ArgoCD).*
      receiver: 'cicd-receiver'
      group_by: ['alertname', 'namespace']
```

### 4. Inhibit Rules

**抑制规则**: 当 critical 告警触发时，抑制相同 alertname、namespace、instance 的 warning 告警

```yaml
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace', 'instance']
```

### 5. Notification Receivers

**当前配置**: Webhook 接收器（占位符 URL）

```yaml
receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true
  - name: 'critical-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook/critical'
        send_resolved: true
  - name: 'warning-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook/warning'
        send_resolved: true
  - name: 'cicd-receiver'
    webhook_configs:
      - url: 'http://localhost:5001/webhook/cicd'
        send_resolved: true
```

**扩展选项**:
- 邮件通知（需配置 SMTP）
- 钉钉机器人
- 企业微信机器人
- Slack/Teams Webhook

## Access Points

| 服务 | 地址 | 说明 |
|------|------|------|
| AlertManager UI | http://182.42.82.135:30903 | 告警管理界面 |
| AlertManager API | http://182.42.82.135:30903/api/v2 | REST API |
| Prometheus Alerts | http://182.42.82.135:30909/alerts | 告警状态 |
| Grafana | http://182.42.82.135:30300 | 监控面板 |

## Verification Checklist

- [x] AlertManager Pod 运行正常
- [x] AlertManager Service (NodePort 30903) 可访问
- [x] CI/CD 告警规则 (cicd-alerting-rules) 已部署
- [x] 基础设施告警规则 (infrastructure-alerting-rules) 已部署
- [x] 告警规则已加载到 Prometheus
- [x] AlertManager 接收到告警
- [x] 路由配置正确
- [x] 抑制规则配置正确

## Future Enhancements

1. **通知渠道扩展**: 配置实际的 Webhook URL（钉钉/企业微信）
2. **告警模板**: 自定义告警消息模板
3. **Grafana 告警面板**: 添加告警状态可视化面板
4. **告警静默**: 配置维护窗口静默规则
5. **告警升级**: 配置告警升级策略
