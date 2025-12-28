# 监控系统部署指南

使用 Prometheus + Grafana 构建监控告警系统。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      监控架构                                │
│                                                             │
│  K8s 集群                                                   │
│  ├── Pod metrics ──┐                                        │
│  ├── Node metrics ─┼──▶ Prometheus ──▶ Grafana             │
│  └── App metrics ──┘         │                              │
│                              ▼                              │
│                        AlertManager ──▶ 钉钉/Slack          │
└─────────────────────────────────────────────────────────────┘
```

## 部署方式

推荐使用 **kube-prometheus-stack** Helm Chart，一键部署：
- Prometheus
- Grafana
- AlertManager
- Node Exporter
- kube-state-metrics

## 部署步骤

### 1. 添加 Helm 仓库

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. 创建 values 文件

```yaml
# prometheus-values.yaml
grafana:
  adminPassword: "admin123"
  service:
    type: NodePort
    nodePort: 30300

prometheus:
  service:
    type: NodePort
    nodePort: 30090

alertmanager:
  service:
    type: NodePort
    nodePort: 30093
```

### 3. 安装

```bash
kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus-values.yaml
```

### 4. 验证

```bash
kubectl get pods -n monitoring
```

### 5. 访问

| 服务 | 地址 |
|------|------|
| Grafana | http://<MASTER_IP>:30300 |
| Prometheus | http://<MASTER_IP>:30090 |
| AlertManager | http://<MASTER_IP>:30093 |

## 监控 DevOps 组件

### Tekton 监控

```yaml
# 启用 Tekton metrics
kubectl apply -f tekton-metrics.yaml
```

### ArgoCD 监控

ArgoCD 默认暴露 metrics，添加 ServiceMonitor：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
  - port: metrics
```

### Harbor 监控

Harbor 支持 Prometheus metrics，配置 ServiceMonitor 即可。

## 告警配置

### 钉钉告警

```yaml
# alertmanager-config.yaml
receivers:
- name: 'dingtalk'
  webhook_configs:
  - url: 'https://oapi.dingtalk.com/robot/send?access_token=xxx'
```

## 目录结构

```
08_monitoring/
├── README.md
├── install/
│   └── prometheus-values.yaml
├── dashboards/
│   ├── tekton-dashboard.json
│   ├── argocd-dashboard.json
│   └── harbor-dashboard.json
└── alerts/
    └── alertmanager-config.yaml
```

## 下一步

1. 安装 kube-prometheus-stack
2. 导入 Grafana Dashboard
3. 配置告警规则
4. 配置告警通知
