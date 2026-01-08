# 监控系统部署指南

> 🎯 使用 Prometheus + Grafana 构建 DevOps 平台监控体系

## 当前状态

**更新时间**: 2026-01-04

| 项目 | 状态 | 说明 |
|------|------|------|
| Helm Chart | ✅ 已安装 | kube-prometheus-stack v72.6.2 |
| Node Exporter | ✅ 运行中 | 3/3 节点已部署 |
| Prometheus Operator | ✅ 运行中 | 1/1 副本 |
| Grafana | ✅ 运行中 | 1/1 副本 |
| kube-state-metrics | ✅ 运行中 | 1/1 副本 |
| Prometheus | ✅ 运行中 | 1/1 副本 |
| AlertManager | ✅ 运行中 | 1/1 副本，NodePort 30903 |
| 所有镜像 | ✅ 已导入 | 使用华为云 x86_64 镜像 |
| 访问测试 | ✅ 正常 | Grafana、Prometheus 和 AlertManager 可访问 |
| Tekton ServiceMonitor | ✅ 已部署 | 监控 Tekton Pipeline |
| ArgoCD ServiceMonitor | ✅ 已部署 | 监控 ArgoCD 应用 |
| DevOps Dashboard | ✅ 已导入 | Grafana Dashboard ID: 1 |
| CI/CD 告警规则 | ✅ 已部署 | Tekton 和 ArgoCD 告警规则 |
| 基础设施告警规则 | ✅ 已部署 | 节点和 Pod 告警规则 |
| 验证系统 | ✅ 已完成 | 所有验证项通过（7/7） |

---

## 部署进度记录

### 2026-01-03 进度

**已完成：**
1. ✅ 本地拉取所有镜像（使用代理 + 华为云镜像源）
2. ✅ 导出镜像为 tar 文件（/tmp/monitoring-images/）
3. ✅ 上传镜像到 master 节点（182.42.82.135）
4. ✅ 上传镜像到 worker1 节点（182.42.80.121）
5. ✅ 上传镜像到 worker2 节点（182.42.95.71）
6. ✅ master 节点导入镜像完成

**下一步：**
```bash
# 1. 在 worker1 导入镜像
ssh root@182.42.80.121 '
for f in /tmp/grafana.tar /tmp/k8s-sidecar.tar /tmp/prometheus-operator.tar /tmp/prometheus.tar /tmp/kube-state-metrics.tar /tmp/prometheus-config-reloader.tar; do
  echo "导入 $f..."
  ctr -n k8s.io images import $f
done
'

# 2. 在 worker2 导入镜像
ssh root@182.42.95.71 '
for f in /tmp/grafana.tar /tmp/k8s-sidecar.tar /tmp/prometheus-operator.tar /tmp/prometheus.tar /tmp/kube-state-metrics.tar /tmp/prometheus-config-reloader.tar; do
  echo "导入 $f..."
  ctr -n k8s.io images import $f
done
'

# 3. 删除 Pod 让其重新拉取镜像
ssh root@182.42.82.135 'kubectl delete pods -n monitoring --all'

# 4. 验证 Pod 状态
ssh root@182.42.82.135 'kubectl get pods -n monitoring -w'
```

### 镜像文件位置

| 节点 | 路径 | 状态 |
|------|------|------|
| master (182.42.82.135) | /tmp/*.tar | ✅ 已导入 |
| worker1 (182.42.80.121) | /tmp/*.tar | ⏳ 待导入 |
| worker2 (182.42.95.71) | /tmp/*.tar | ⏳ 待导入 |

---

## 国内镜像源（重要）

由于服务器无法直接访问 Docker Hub / registry.k8s.io，需要使用国内镜像源。

### 华为云镜像源（推荐）

华为云提供了 K8s 相关镜像的国内镜像，**无需代理即可访问**：

```bash
# kube-state-metrics
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0

# 其他 K8s 镜像格式
# swr.cn-north-4.myhuaweicloud.com/ddn-k8s/<原始镜像路径>
```

### 阿里云镜像源

```bash
# 部分镜像可用
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/<镜像名>:<版本>
```

### Quay.io（需代理）

```bash
# Prometheus 相关镜像
docker pull quay.io/prometheus/prometheus:v3.2.1
docker pull quay.io/prometheus/node-exporter:v1.9.0
docker pull quay.io/prometheus-operator/prometheus-operator:v0.82.2
docker pull quay.io/kiwigrid/k8s-sidecar:1.30.3
```

### 镜像对照表

| 组件 | 原始镜像 | 国内镜像源 |
|------|---------|-----------|
| kube-state-metrics | registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 |
| Prometheus | quay.io/prometheus/prometheus:v3.2.1 | quay.io (需代理) |
| Grafana | grafana/grafana:11.5.2 | Docker Hub (需代理) |
| Node Exporter | quay.io/prometheus/node-exporter:v1.9.0 | quay.io (需代理) |
| Prometheus Operator | quay.io/prometheus-operator/prometheus-operator:v0.82.2 | quay.io (需代理) |
| k8s-sidecar | quay.io/kiwigrid/k8s-sidecar:1.30.3 | quay.io (需代理) |

---

## 快速开始

### 方式一：使用安装脚本

```bash
# 在服务器上执行
cd /path/to/08_monitoring/install
chmod +x install.sh
./install.sh
```

### 方式二：手动安装

```bash
# 1. 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. 创建命名空间
kubectl create namespace monitoring

# 3. 安装（使用自定义配置）
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f install/values.yaml

# 4. 验证
kubectl get pods -n monitoring
```

### 验证安装

```bash
kubectl get pods -n monitoring
```

预期输出：
```
NAME                                                     READY   STATUS    RESTARTS   AGE
prometheus-grafana-xxx                                   3/3     Running   0          5m
prometheus-kube-prometheus-operator-xxx                  1/1     Running   0          5m
prometheus-kube-state-metrics-xxx                        1/1     Running   0          5m
prometheus-prometheus-node-exporter-xxx                  1/1     Running   0          5m
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          5m
```

---

## 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| Grafana | http://<MASTER_IP>:30300 | admin / admin123 |
| Prometheus | http://<MASTER_IP>:30909 | 指标查询 |
| AlertManager | http://<MASTER_IP>:30903 | 告警管理 |

---

## 目录结构

```
08_monitoring/
├── README.md                    # 本文档
├── VERIFICATION.md              # 验证文档
├── DESIGN.md                    # 设计方案
├── troubleshooting.md           # 故障排查指南
│
├── install/
│   ├── values.yaml              # Helm values 配置（包含 AlertManager 配置）
│   ├── install.sh               # 安装脚本
│   ├── cicd-alerting-rules.yaml # CI/CD 告警规则
│   └── infrastructure-alerting-rules.yaml # 基础设施告警规则
│
├── servicemonitors/             # ServiceMonitor 配置
│   ├── tekton-servicemonitor.yaml
│   ├── argocd-servicemonitor.yaml
│   └── harbor-servicemonitor.yaml
│
├── dashboards/                  # 自定义 Dashboard
│   ├── devops-overview.json
│   └── service-test.json
│
└── verify-monitoring.sh         # 一键验证脚本
```

---

## 监控范围

### 基础设施
- Node CPU/内存/磁盘使用率
- Pod 状态和资源使用
- 网络流量

### DevOps 组件
- Tekton Pipeline 执行情况
- ArgoCD 同步状态
- Harbor 镜像拉取量
- Argo Rollouts 发布状态

### 业务应用
- service-test 微服务指标

### 告警规则
- CI/CD 告警：Tekton Pipeline 失败、ArgoCD 应用异常
- 基础设施告警：节点资源使用率过高、Pod 异常状态

---

## ServiceMonitor 配置

### Tekton ServiceMonitor

**文件**: [servicemonitors/tekton-servicemonitor.yaml](./servicemonitors/tekton-servicemonitor.yaml)

监控 Tekton Pipeline Controller 的指标：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-servicemonitor
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
      app.kubernetes.io/instance: default
      app.kubernetes.io/name: controller
      app.kubernetes.io/part-of: tekton-pipelines
  endpoints:
    - port: http-metrics
      interval: 30s
      path: /metrics
```

**部署**:
```bash
kubectl apply -f servicemonitors/tekton-servicemonitor.yaml
```

**验证**:
```bash
kubectl get servicemonitor tekton-servicemonitor -n monitoring
```

### ArgoCD ServiceMonitor

**文件**: [servicemonitors/argocd-servicemonitor.yaml](./servicemonitors/argocd-servicemonitor.yaml)

监控 ArgoCD Application Controller、Repo Server 和 Server 的指标：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-application-controller-servicemonitor
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
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-servicemonitor
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
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-servicemonitor
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
```

**部署**:
```bash
kubectl apply -f servicemonitors/argocd-servicemonitor.yaml
```

**验证**:
```bash
kubectl get servicemonitor -n monitoring | grep argocd
```

**预期输出**:
```
NAME                                                 AGE
argocd-application-controller-servicemonitor        5m
argocd-repo-server-servicemonitor                    5m
argocd-server-servicemonitor                         5m
```

**重要提示**:
- ServiceMonitor 必须使用端口名称而非端口号
- 确保 ArgoCD Services 的端口名称与 ServiceMonitor 中指定的端口名称匹配
- 确保 ArgoCD Services 的标签与 ServiceMonitor 的 selector 匹配

### 验证 Prometheus Targets

```bash
# 端口转发 Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 --address 0.0.0.0 &

# 访问 http://<MASTER_IP>:9090/targets
# 应该看到 tekton-servicemonitor 和 argocd-servicemonitor 的 targets
```

---

## Grafana Dashboard

### DevOps Platform Overview

**文件**: [dashboards/devops-overview.json](./dashboards/devops-overview.json)

**Dashboard ID**: 1
**UID**: devops-overview
**URL**: http://<MASTER_IP>:30300/d/devops-overview/devops-platform-overview

**包含的面板**:
1. **Tekton Pods** - Tekton 命名空间中的 Pod 数量
2. **ArgoCD Pods** - ArgoCD 命名空间中的 Pod 数量
3. **Cluster CPU Usage** - 集群 CPU 使用率
4. **Cluster Memory Usage** - 集群内存使用率
5. **Tekton Pipeline Duration** - Tekton Pipeline 执行时长趋势
6. **ArgoCD Application Sync Status** - ArgoCD 应用同步状态（成功/失败）
7. **Node CPU Usage** - 各节点 CPU 使用率
8. **Node Memory Usage** - 各节点内存使用率

**导入 Dashboard**:

方法一：通过 Grafana UI
1. 访问 Grafana: http://<MASTER_IP>:30300
2. 登录 (admin / admin123)
3. 点击 "+" -> "Import dashboard"
4. 上传 JSON 文件或粘贴 JSON 内容
5. 点击 "Load" 然后 "Import"

方法二：通过 API
```bash
# 准备导入文件
python3 << 'PYEOF'
import json

dashboard_file = "/path/to/dashboards/devops-overview.json"
output_file = "/tmp/grafana-dashboard-import.json"

with open(dashboard_file, 'r') as f:
    dashboard = json.load(f)

import_data = {
    "dashboard": dashboard,
    "overwrite": True,
    "message": "Imported DevOps Overview Dashboard"
}

with open(output_file, 'w') as f:
    json.dump(import_data, f, indent=2)
PYEOF

# 导入到 Grafana
curl -X POST -H "Content-Type: application/json" \
  -d @/tmp/grafana-dashboard-import.json \
  http://admin:admin123@<MASTER_IP>:30300/api/dashboards/db
```

**更新 Dashboard**:
```bash
# 使用相同的 API 调用，设置 overwrite: true
curl -X POST -H "Content-Type: application/json" \
  -d @/tmp/grafana-dashboard-import.json \
  http://admin:admin123@<MASTER_IP>:30300/api/dashboards/db
```

---

## 内置 Dashboard

安装后 Grafana 自带以下 Dashboard：

| Dashboard | 用途 |
|-----------|------|
| Kubernetes / Compute Resources / Cluster | 集群资源概览 |
| Kubernetes / Compute Resources / Namespace (Pods) | Pod 资源监控 |
| Kubernetes / Compute Resources / Node (Pods) | 节点资源监控 |
| Node Exporter / Nodes | 节点详细指标 |

---

## AlertManager 配置

### 部署 AlertManager

AlertManager 已通过 kube-prometheus-stack Helm Chart 部署，配置在 [install/values.yaml](./install/values.yaml) 中。

**关键配置**:
- NodePort: 30903
- 镜像: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/alertmanager:v0.27.0
- 数据保留: 120h

### 告警路由规则

AlertManager 配置了基于严重性的告警路由：

| 接收器 | 严重性 | 重复间隔 | 说明 |
|--------|--------|---------|------|
| critical-receiver | critical | 1h | 关键告警，快速通知 |
| warning-receiver | warning | 4h | 警告告警，常规通知 |
| cicd-receiver | Tekton/ArgoCD | 4h | CI/CD 专用接收器 |
| default-receiver | 其他 | 4h | 默认接收器 |

### 告警抑制规则

配置了告警抑制规则，避免告警风暴：
- 当 critical 级别告警触发时，抑制相同 alertname、namespace 和 instance 的 warning 级别告警

### CI/CD 告警规则

**文件**: [install/cicd-alerting-rules.yaml](./install/cicd-alerting-rules.yaml)

**Tekton 告警**:
- `TektonPipelineRunFailed` - PipelineRun 执行失败
- `TektonPipelineLongRunning` - Pipeline 执行时间过长（> 30分钟）

**ArgoCD 告警**:
- `ArgoCDAppDegraded` - 应用健康状态异常
- `ArgoCDAppSyncFailed` - 应用同步失败
- `ArgoCDAppOutOfSync` - 应用配置与期望状态不一致

### 基础设施告警规则

**文件**: [install/infrastructure-alerting-rules.yaml](./install/infrastructure-alerting-rules.yaml)

**节点告警**:
- `NodeHighCPUUsage` - CPU 使用率 > 80%
- `NodeHighMemoryUsage` - 内存使用率 > 80%
- `NodeDiskSpaceLow` - 磁盘使用率 > 85%

**Pod 告警**:
- `PodCrashLoopBackOff` - Pod 处于 CrashLoopBackOff 状态
- `PodOOMKilled` - Pod 因 OOM 被终止
- `PodNotReady` - Pod 未就绪超过 10 分钟

### 部署告警规则

```bash
# 部署 CI/CD 告警规则
kubectl apply -f install/cicd-alerting-rules.yaml

# 部署基础设施告警规则
kubectl apply -f install/infrastructure-alerting-rules.yaml
```

### 验证告警规则

```bash
# 1. 验证 PrometheusRule 资源
kubectl get prometheusrules -n monitoring

# 2. 验证规则已加载到 Prometheus
curl -s http://<MASTER_IP>:30909/api/v1/rules | python3 -m json.tool | grep '"name"'

# 3. 验证 AlertManager 配置
curl -s http://<MASTER_IP>:30903/api/v2/status | python3 -m json.tool

# 4. 查看 AlertManager 接收器
curl -s http://<MASTER_IP>:30903/api/v2/status | python3 -m json.tool | grep -A 20 '"receivers"'
```

### 测试告警

创建一个测试告警来验证 AlertManager 功能：

```bash
# 1. 创建一个临时的 PrometheusRule
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert-rule
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: test.rules
      rules:
        - alert: TestAlert
          expr: vector(1)
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "测试告警"
            description: "这是一个测试告警"
EOF

# 2. 等待 1-2 分钟后查看告警
curl -s http://<MASTER_IP>:30909/api/v1/alerts | python3 -m json.tool | grep TestAlert

# 3. 查看 AlertManager 接收到的告警
curl -s http://<MASTER_IP>:30903/api/v2/alerts | python3 -m json.tool | grep TestAlert

# 4. 删除测试规则
kubectl delete prometheusrule test-alert-rule -n monitoring
```

### 配置通知接收器

当前配置使用 webhook 作为通知方式，需要根据实际需求修改 webhook URL：

修改 [install/values.yaml](./install/values.yaml) 中的 receivers 配置：

```yaml
receivers:
  - name: 'critical-receiver'
    webhook_configs:
      - url: 'http://your-webhook-url/critical'  # 替换为实际的 webhook URL
        send_resolved: true
  
  - name: 'warning-receiver'
    webhook_configs:
      - url: 'http://your-webhook-url/warning'  # 替换为实际的 webhook URL
        send_resolved: true
  
  - name: 'cicd-receiver'
    webhook_configs:
      - url: 'http://your-webhook-url/cicd'  # 替换为实际的 webhook URL
        send_resolved: true
```

重新部署：

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f install/values.yaml
```

---

## 故障排查

### 问题 1: Pod 处于 CrashLoopBackOff 状态

**症状**: Pod 不断重启，状态为 CrashLoopBackOff

**可能原因**:
1. 镜像架构不匹配（arm64 镜像运行在 x86_64 节点上）
2. 配置错误
3. 资源不足

**排查步骤**:
```bash
# 查看 Pod 状态
kubectl get pods -n monitoring

# 查看 Pod 日志
kubectl logs <pod-name> -n monitoring

# 查看事件
kubectl describe pod <pod-name> -n monitoring
```

**解决方案**:
- 检查镜像架构是否匹配节点架构
- 使用正确的镜像源（华为云 x86_64 镜像）

---

### 问题 2: exec format error

**症状**: Pod 日志显示 `exec /bin/prometheus: exec format error`

**原因**: 镜像架构与节点架构不匹配

**排查**:
```bash
# 查看节点架构
kubectl get nodes -o wide

# 查看镜像架构
docker inspect <image> | grep Architecture
```

**解决方案**:
使用华为云 x86_64 镜像替换原始镜像：

```yaml
# values.yaml 配置示例
prometheus:
  prometheusSpec:
    image:
      registry: swr.cn-north-4.myhuaweicloud.com
      repository: ddn-k8s/quay.io/prometheus/prometheus
      tag: v3.2.1

grafana:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/docker.io/grafana/grafana
    tag: "10.4.2"

prometheusOperator:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/quay.io/prometheus-operator/prometheus-operator
    tag: v0.82.2
```

---

### 问题 3: ImagePullBackOff 错误

**症状**: Pod 状态为 ImagePullBackOff

**原因**:
1. 镜像路径错误
2. 镜像不存在
3. 网络问题

**排查**:
```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n monitoring

# 检查镜像是否存在
docker pull <image>
```

**解决方案**:
1. 使用正确的镜像路径
2. 提前拉取镜像到所有节点
3. 使用国内镜像源（华为云）

```bash
# 在所有节点提前拉取镜像
# Master 节点
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1

# Worker 节点（使用 containerd）
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1
```

---

### 问题 4: TLS secret not found

**症状**: Prometheus Operator 启动失败，日志显示 `secret "prometheus-kube-prometheus-admission" not found`

**原因**: TLS 配置启用但缺少 secret

**解决方案**:
在 values.yaml 中禁用 TLS：

```yaml
prometheusOperator:
  tls:
    enabled: false
```

然后重新部署：
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

### 问题 5: Grafana sidecar 容器失败

**症状**: Grafana Pod 中 sidecar 容器不断重启

**原因**: sidecar 镜像架构不匹配或配置问题

**解决方案**:
在 values.yaml 中禁用 sidecar：

```yaml
grafana:
  sidecar:
    dashboards:
      enabled: false
    datasources:
      enabled: false
```

---

### 问题 6: Helm repo not found

**症状**: 执行 helm install 时报错 `Error: repo "prometheus-community" not found`

**原因**: Helm 仓库未添加

**解决方案**:
```bash
# 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 更新仓库
helm repo update
```

---

### 问题 7: kube-state-metrics ImagePullBackOff

**症状**: kube-state-metrics Pod 无法拉取镜像

**原因**: 原始镜像路径 `registry.k8s.io` 在国内无法访问

**解决方案**:
使用华为云镜像源：

```yaml
kube-state-metrics:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics
    tag: v2.15.0
```

---

## 镜像架构问题总结

### 问题背景
集群节点为 x86_64 架构，但部分默认镜像为 arm64 架构，导致 `exec format error`。

### 受影响的组件
1. Grafana (grafana/grafana:11.5.2)
2. Prometheus Operator (quay.io/prometheus-operator/prometheus-operator:v0.82.2)
3. Prometheus (quay.io/prometheus/prometheus:v3.2.1)
4. k8s-sidecar (quay.io/kiwigrid/k8s-sidecar:1.30.3)

### 解决方案
使用华为云 x86_64 镜像源：

| 组件 | 原始镜像 | 华为云 x86_64 镜像 |
|------|---------|-------------------|
| Grafana | grafana/grafana:11.5.2 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/grafana/grafana:10.4.2 |
| Prometheus Operator | quay.io/prometheus-operator/prometheus-operator:v0.82.2 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus-operator/prometheus-operator:v0.82.2 |
| Prometheus | quay.io/prometheus/prometheus:v3.2.1 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1 |
| kube-state-metrics | registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 |

### 部署流程
1. 修改 values.yaml，使用华为云镜像
2. 在所有节点提前拉取镜像
3. 执行 helm upgrade 更新部署
4. 等待 Pod 启动并验证状态

---

## 验证系统

### 一键验证脚本

使用 [verify-monitoring.sh](./verify-monitoring.sh) 脚本可以自动化验证监控系统的所有关键组件：

```bash
./verify-monitoring.sh
```

**验证内容**:
1. ServiceMonitor 存在性验证
2. Prometheus Targets 状态验证
3. Tekton 指标数据验证
4. ArgoCD 指标数据验证
5. Grafana Dashboard 验证

**最新验证结果** (2026-01-03):
```
[INFO] =========================================
[INFO] 监控系统一键验证脚本
[INFO] =========================================

[INFO] 步骤 1: 验证 ServiceMonitor 存在性
[INFO] ✓ Tekton ServiceMonitor 存在
[INFO] ✓ ArgoCD ServiceMonitor 存在

[INFO] 步骤 2: 验证 Prometheus Targets 状态
[INFO] Prometheus Pod: prometheus-prometheus-kube-prometheus-prometheus-0
[INFO] ✓ 找到       20 个 Tekton 相关的 Target
[INFO] ✓ 找到       14 个 ArgoCD 相关的 Target

[INFO] 步骤 3: 验证 Tekton 指标数据
[INFO] ✓ Tekton 指标数据存在

[INFO] 步骤 4: 验证 ArgoCD 指标数据
[INFO] ✓ ArgoCD 指标数据存在

[INFO] 步骤 5: 验证 Grafana Dashboard
[INFO] ✓ DevOps Platform Overview Dashboard 存在

[INFO] =========================================
[INFO] 验证报告
[INFO] =========================================

[INFO] 通过: 7
[INFO] 失败: 0

[INFO] ✓ 所有验证通过！
```

### 详细验证文档

完整的验证流程和故障排查指南请参考 [VERIFICATION.md](./VERIFICATION.md)，包含：

- 服务器信息（Master/Worker IP、SSH 登录方式、服务访问地址）
- 5 个验证步骤的详细说明
- 每步的验证命令、成功/失败标准、失败处理方法
- 验证结果汇总表
- 常见问题排查指南

### 手动验证步骤

如果需要手动验证，可以按照以下步骤：

#### 1. 验证 ServiceMonitor 存在性

```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get servicemonitors -n monitoring'
```

预期输出包含：
- `tekton-servicemonitor`
- `argocd-application-controller-servicemonitor`
- `argocd-repo-server-servicemonitor`

#### 2. 验证 Prometheus Targets 状态

```bash
# 端口转发 Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 --address 0.0.0.0 &

# 访问 http://182.42.82.135:9090/targets
# 应该看到 Tekton 和 ArgoCD 相关的 targets 状态为 "up"
```

#### 3. 验证指标数据

Tekton 指标：
```bash
# 在 Prometheus UI 中查询
up{job=~".*tekton.*"}
```

ArgoCD 指标：
```bash
# 在 Prometheus UI 中查询
up{job=~".*argocd.*"}
```

#### 4. 验证 Grafana Dashboard

访问 Grafana: http://182.42.82.135:30300
- 登录 (admin / admin123)
- 打开 "DevOps Platform Overview" Dashboard
- 验证所有面板都有数据显示

### 验证结果汇总表

| 验证项 | 状态 | 备注 |
|--------|------|------|
| ServiceMonitor 存在性 | ✅ 通过 | Tekton 和 ArgoCD ServiceMonitor 都存在 |
| Prometheus Targets 状态 | ✅ 通过 | 20 个 Tekton Target，14 个 ArgoCD Target |
| Tekton 指标数据 | ✅ 通过 | 指标数据正常采集 |
| ArgoCD 指标数据 | ✅ 通过 | 指标数据正常采集 |
| Grafana Dashboard | ✅ 通过 | DevOps Platform Overview Dashboard 已导入 |

---

## 常用命令

```bash
# 查看 Pod 状态
kubectl get pods -n monitoring

# 查看 Service
kubectl get svc -n monitoring

# 查看 Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# 然后访问 http://localhost:9090/targets

# 重启 Grafana
kubectl rollout restart deployment prometheus-grafana -n monitoring

# 查看 Pod 日志
kubectl logs <pod-name> -n monitoring

# 查看 Pod 事件
kubectl describe pod <pod-name> -n monitoring

# 卸载
helm uninstall prometheus -n monitoring

# 获取 Grafana 密码
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

---

## 相关文档

- [DESIGN.md](./DESIGN.md) - 详细设计方案
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)

---

## 进度

1. ✅ 安装 kube-prometheus-stack (Helm Chart)
2. ✅ 解决镜像架构问题（使用华为云 x86_64 镜像）
3. ✅ 解决 TLS secret 问题
4. ✅ 解决 sidecar 容器问题
5. ✅ 所有 Pod 正常运行
6. ✅ Grafana 和 Prometheus 可访问
7. ✅ 配置 Tekton ServiceMonitor
8. ✅ 配置 ArgoCD ServiceMonitor
9. ✅ 导入 DevOps Overview Dashboard
10. ✅ 验证所有监控目标正常
11. ✅ 创建验证文档 (VERIFICATION.md)
12. ✅ 创建一键验证脚本 (verify-monitoring.sh)
13. ✅ 执行验证并确认所有项通过
