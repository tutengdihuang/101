# 安装部署指南

> 🚀 从零开始部署 Prometheus + Grafana + AlertManager 监控栈

## 一、前置条件

### 1.1 环境要求

| 组件 | 最低要求 | 推荐配置 |
|------|---------|---------|
| Kubernetes | 1.25+ | 1.28+ |
| Helm | 3.0+ | 3.12+ |
| 节点内存 | 4GB | 8GB+ |
| 节点磁盘 | 20GB | 50GB+ |

### 1.2 检查环境

```bash
# 检查 Kubernetes 版本
kubectl version --short

# 检查 Helm 版本
helm version --short

# 检查节点资源
kubectl top nodes
```

---

## 二、安装步骤

### 2.1 添加 Helm 仓库

```bash
# 添加 prometheus-community 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 更新仓库
helm repo update
```

### 2.2 创建命名空间

```bash
kubectl create namespace monitoring
```

### 2.3 准备 values.yaml

创建 `values.yaml` 配置文件：

```yaml
# Prometheus 配置
prometheus:
  prometheusSpec:
    retention: 7d                    # 数据保留 7 天
    scrapeInterval: 30s              # 抓取间隔
    evaluationInterval: 30s          # 规则评估间隔
    
    # 资源限制
    resources:
      requests:
        memory: 1Gi
        cpu: 500m
      limits:
        memory: 2Gi
        cpu: 1000m
    
    # 存储配置（可选）
    # storageSpec:
    #   volumeClaimTemplate:
    #     spec:
    #       accessModes: ["ReadWriteOnce"]
    #       resources:
    #         requests:
    #           storage: 50Gi
  
  # NodePort 暴露
  service:
    type: NodePort
    nodePort: 30909

# Grafana 配置
grafana:
  adminPassword: admin123           # 管理员密码
  
  service:
    type: NodePort
    nodePort: 30300
  
  # 资源限制
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 200m

# AlertManager 配置
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi
        cpu: 100m
  
  service:
    type: NodePort
    nodePort: 30903
  
  # 告警配置
  config:
    global:
      resolve_timeout: 5m
    
    route:
      receiver: 'default-receiver'
      group_by: ['alertname', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    
    receivers:
      - name: 'default-receiver'
        webhook_configs:
          - url: 'http://webhook-server:5001/webhook'
            send_resolved: true

# Node Exporter 配置
nodeExporter:
  enabled: true

# Kube-State-Metrics 配置
kubeStateMetrics:
  enabled: true

# 禁用不需要的组件（可选）
kubeEtcd:
  enabled: false
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeProxy:
  enabled: false
```

### 2.4 安装 kube-prometheus-stack

```bash
# 安装
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml

# 等待 Pod 就绪
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s
```

### 2.5 验证安装

```bash
# 查看所有 Pod
kubectl get pods -n monitoring

# 查看 Service
kubectl get svc -n monitoring

# 查看 CRD
kubectl get crd | grep monitoring
```

---

## 三、访问服务

### 3.1 获取访问地址

```bash
# 获取节点 IP
kubectl get nodes -o wide

# 访问地址
# Grafana:     http://<node-ip>:30300
# Prometheus:  http://<node-ip>:30909
# AlertManager: http://<node-ip>:30903
```

### 3.2 当前环境访问地址

| 服务 | 地址 | 账号密码 |
|------|------|---------|
| Grafana | http://182.42.82.135:30300 | admin / admin123 |
| Prometheus | http://182.42.82.135:30909 | - |
| AlertManager | http://182.42.82.135:30903 | - |

---

## 四、镜像配置（国内环境）

如果拉取镜像失败，可以使用国内镜像源：

```yaml
# values.yaml 中添加镜像配置
prometheus:
  prometheusSpec:
    image:
      registry: swr.cn-north-4.myhuaweicloud.com
      repository: ddn-k8s/quay.io/prometheus/prometheus
      tag: v3.2.1

alertmanager:
  alertmanagerSpec:
    image:
      registry: swr.cn-north-4.myhuaweicloud.com
      repository: ddn-k8s/quay.io/prometheus/alertmanager
      tag: v0.27.0

grafana:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/docker.io/grafana/grafana
    tag: 10.4.2

nodeExporter:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/quay.io/prometheus/node-exporter
    tag: v1.9.0

kubeStateMetrics:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics
    tag: v2.15.0

prometheusOperator:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/quay.io/prometheus-operator/prometheus-operator
    tag: v0.82.2
```

---

## 五、升级和卸载

### 5.1 升级

```bash
# 更新 values.yaml 后升级
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

### 5.2 卸载

```bash
# 卸载 Helm release
helm uninstall prometheus -n monitoring

# 删除 CRD（可选，会删除所有监控配置）
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd scrapeconfigs.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com

# 删除命名空间
kubectl delete namespace monitoring
```

---

## 六、常见问题

### Q1: Pod 一直 Pending

```bash
# 检查 Pod 事件
kubectl describe pod <pod-name> -n monitoring

# 常见原因：
# 1. 资源不足 → 调整 resources 配置
# 2. 镜像拉取失败 → 使用国内镜像源
# 3. PVC 无法绑定 → 检查 StorageClass
```

### Q2: Prometheus 无法抓取目标

```bash
# 检查 ServiceMonitor
kubectl get servicemonitor -n monitoring

# 检查 Prometheus 配置
kubectl get prometheus -n monitoring -o yaml

# 检查 Targets 页面
# http://<node-ip>:30909/targets
```

### Q3: Grafana 无法登录

```bash
# 重置密码
kubectl exec -n monitoring <grafana-pod> -- grafana-cli admin reset-admin-password newpassword
```

---

## 七、下一步

- [添加监控目标](add-servicemonitor.md)
- [创建 Dashboard](create-dashboard.md)
- [创建告警规则](create-alert-rule.md)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- kube-prometheus-stack：v72.6.2
