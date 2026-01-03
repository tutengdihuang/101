# 监控系统部署指南

> 🎯 使用 Prometheus + Grafana 构建 DevOps 平台监控体系

## 当前状态

**更新时间**: 2026-01-03

| 项目 | 状态 | 说明 |
|------|------|------|
| Helm Chart | ✅ 已安装 | kube-prometheus-stack v72.6.2 |
| Node Exporter | ✅ 运行中 | 3/3 节点已部署 |
| Prometheus Operator | ✅ 运行中 | 1/1 副本 |
| Grafana | ✅ 运行中 | 1/1 副本 |
| kube-state-metrics | ✅ 运行中 | 1/1 副本 |
| Prometheus | ✅ 运行中 | 1/1 副本 |
| 所有镜像 | ✅ 已导入 | 使用华为云 x86_64 镜像 |
| 访问测试 | ✅ 正常 | Grafana 和 Prometheus 可访问 |

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

---

## 目录结构

```
08_monitoring/
├── README.md                    # 本文档
├── DESIGN.md                    # 设计方案
│
├── install/
│   ├── values.yaml              # Helm values 配置
│   └── install.sh               # 安装脚本
│
├── servicemonitors/             # ServiceMonitor 配置
│   ├── tekton-servicemonitor.yaml
│   ├── argocd-servicemonitor.yaml
│   └── harbor-servicemonitor.yaml
│
└── dashboards/                  # 自定义 Dashboard
    ├── devops-overview.json
    └── service-test.json
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
7. ⏳ 配置 DevOps 组件 ServiceMonitor（可选）
8. ⏳ 导入自定义 Dashboard（可选）
9. ⏳ 配置告警规则（可选）
