# 监控系统部署指南

> 🎯 使用 Prometheus + Grafana 构建 DevOps 平台监控体系

## 当前状态

**更新时间**: 2026-01-03

| 项目 | 状态 | 说明 |
|------|------|------|
| Helm Chart | ✅ 已安装 | kube-prometheus-stack v72.6.2 |
| Node Exporter | ✅ 运行中 | 3/3 节点已部署 |
| 镜像拉取 | ✅ 已完成 | 本地已拉取所有镜像 |
| 镜像上传 | ✅ 已完成 | 已上传到 master/worker1/worker2 |
| 镜像导入 | ⏳ 进行中 | master 已导入，worker 待导入 |
| Prometheus Operator | ⏳ 待启动 | 等待镜像导入 |
| Grafana | ⏳ 待启动 | 等待镜像导入 |
| kube-state-metrics | ⏳ 待启动 | 等待镜像导入 |
| AlertManager | ⏳ 暂不启用 | 告警通知 |

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

# 卸载
helm uninstall prometheus -n monitoring
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
2. ✅ 本地拉取镜像（代理 + 华为云镜像源）
3. ✅ 上传镜像到所有节点
4. ⏳ 导入镜像到 worker 节点
5. ⏳ 验证 Pod 运行状态
6. ⏳ 验证 Grafana 访问
7. ⏳ 配置 DevOps 组件 ServiceMonitor（可选）
8. ⏳ 导入自定义 Dashboard（可选）
9. ⏳ 配置告警规则（可选）
