# 监控系统故障排查指南

> 📋 记录监控系统部署过程中遇到的所有问题及解决方案

## 目录

- [问题 1: Pod 处于 CrashLoopBackOff 状态](#问题-1-pod-处于-crashloopbackoff-状态)
- [问题 2: exec format error](#问题-2-exec-format-error)
- [问题 3: ImagePullBackOff 错误](#问题-3-imagepullbackoff-错误)
- [问题 4: TLS secret not found](#问题-4-tls-secret-not-found)
- [问题 5: Grafana sidecar 容器失败](#问题-5-grafana-sidecar-容器失败)
- [问题 6: Helm repo not found](#问题-6-helm-repo-not-found)
- [问题 7: kube-state-metrics ImagePullBackOff](#问题-7-kube-state-metrics-imagepullbackoff)
- [镜像架构问题总结](#镜像架构问题总结)

---

## 问题 1: Pod 处于 CrashLoopBackOff 状态

### 症状

Pod 不断重启,状态为 CrashLoopBackOff

```bash
kubectl get pods -n monitoring
```

输出示例:
```
NAME                                                     READY   STATUS             RESTARTS   AGE
prometheus-grafana-xxx                                   0/3     CrashLoopBackOff   5          10m
prometheus-prometheus-kube-prometheus-prometheus-0       0/2     CrashLoopBackOff   3          10m
```

### 可能原因

1. 镜像架构不匹配（arm64 镜像运行在 x86_64 节点上）
2. 配置错误
3. 资源不足

### 排查步骤

```bash
# 1. 查看 Pod 状态
kubectl get pods -n monitoring

# 2. 查看 Pod 日志
kubectl logs <pod-name> -n monitoring

# 3. 查看事件
kubectl describe pod <pod-name> -n monitoring
```

### 解决方案

检查镜像架构是否匹配节点架构,使用正确的镜像源（华为云 x86_64 镜像）

```bash
# 查看节点架构
kubectl get nodes -o wide

# 查看镜像架构
docker inspect <image> | grep Architecture
```

---

## 问题 2: exec format error

### 症状

Pod 日志显示 `exec /bin/prometheus: exec format error`

```bash
kubectl logs prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring
```

输出示例:
```
exec /bin/prometheus: exec format error
```

### 原因

镜像架构与节点架构不匹配

### 排查

```bash
# 1. 查看节点架构
kubectl get nodes -o wide

# 2. 查看镜像架构
docker inspect <image> | grep Architecture
```

### 解决方案

使用华为云 x86_64 镜像替换原始镜像

修改 `values.yaml`:

```yaml
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

重新部署:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## 问题 3: ImagePullBackOff 错误

### 症状

Pod 状态为 ImagePullBackOff

```bash
kubectl get pods -n monitoring
```

输出示例:
```
NAME                                                     READY   STATUS             RESTARTS   AGE
prometheus-kube-state-metrics-xxx                        0/1     ImagePullBackOff   0          5m
```

### 原因

1. 镜像路径错误
2. 镜像不存在
3. 网络问题

### 排查

```bash
# 1. 查看 Pod 详情
kubectl describe pod <pod-name> -n monitoring

# 2. 检查镜像是否存在
docker pull <image>
```

### 解决方案

1. 使用正确的镜像路径
2. 提前拉取镜像到所有节点
3. 使用国内镜像源（华为云）

在所有节点提前拉取镜像:

```bash
# Master 节点
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1

# Worker 节点（使用 containerd）
crictl --runtime-endpoint=unix:///run/containerd/containerd.sock pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1
```

---

## 问题 4: TLS secret not found

### 症状

Prometheus Operator 启动失败,日志显示 `secret "prometheus-kube-prometheus-admission" not found`

```bash
kubectl logs prometheus-kube-prometheus-operator-xxx -n monitoring
```

输出示例:
```
Error: secret "prometheus-kube-prometheus-admission" not found
```

### 原因

TLS 配置启用但缺少 secret

### 解决方案

在 values.yaml 中禁用 TLS:

```yaml
prometheusOperator:
  tls:
    enabled: false
```

重新部署:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## 问题 5: Grafana sidecar 容器失败

### 症状

Grafana Pod 中 sidecar 容器不断重启

```bash
kubectl get pods -n monitoring
```

输出示例:
```
NAME                                                     READY   STATUS             RESTARTS   AGE
prometheus-grafana-xxx                                   1/3     CrashLoopBackOff   10         15m
```

### 原因

sidecar 镜像架构不匹配或配置问题

### 解决方案

在 values.yaml 中禁用 sidecar:

```yaml
grafana:
  sidecar:
    dashboards:
      enabled: false
    datasources:
      enabled: false
```

重新部署:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## 问题 6: Helm repo not found

### 症状

执行 helm install 时报错 `Error: repo "prometheus-community" not found`

```bash
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

输出示例:
```
Error: repo "prometheus-community" not found
```

### 原因

Helm 仓库未添加

### 解决方案

```bash
# 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 更新仓库
helm repo update
```

---

## 问题 7: kube-state-metrics ImagePullBackOff

### 症状

kube-state-metrics Pod 无法拉取镜像

```bash
kubectl get pods -n monitoring
```

输出示例:
```
NAME                                                     READY   STATUS             RESTARTS   AGE
prometheus-kube-state-metrics-xxx                        0/1     ImagePullBackOff   0          5m
```

### 原因

原始镜像路径 `registry.k8s.io` 在国内无法访问

### 解决方案

使用华为云镜像源

修改 `values.yaml`:

```yaml
kube-state-metrics:
  image:
    registry: swr.cn-north-4.myhuaweicloud.com
    repository: ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics
    tag: v2.15.0
```

重新部署:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## 镜像架构问题总结

### 问题背景

集群节点为 x86_64 架构,但部分默认镜像为 arm64 架构,导致 `exec format error`。

### 受影响的组件

1. Grafana (grafana/grafana:11.5.2)
2. Prometheus Operator (quay.io/prometheus-operator/prometheus-operator:v0.82.2)
3. Prometheus (quay.io/prometheus/prometheus:v3.2.1)
4. k8s-sidecar (quay.io/kiwigrid/k8s-sidecar:1.30.3)

### 解决方案

使用华为云 x86_64 镜像源:

| 组件 | 原始镜像 | 华为云 x86_64 镜像 |
|------|---------|-------------------|
| Grafana | grafana/grafana:11.5.2 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/grafana/grafana:10.4.2 |
| Prometheus Operator | quay.io/prometheus-operator/prometheus-operator:v0.82.2 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus-operator/prometheus-operator:v0.82.2 |
| Prometheus | quay.io/prometheus/prometheus:v3.2.1 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/prometheus:v3.2.1 |
| kube-state-metrics | registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 | swr.cn-north-4.myhuaweicloud.com/ddn-k8s/registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.15.0 |

### 部署流程

1. 修改 values.yaml,使用华为云镜像
2. 在所有节点提前拉取镜像
3. 执行 helm upgrade 更新部署
4. 等待 Pod 启动并验证状态

### 验证步骤

```bash
# 1. 查看 Pod 状态
kubectl get pods -n monitoring

# 2. 查看 Pod 日志
kubectl logs <pod-name> -n monitoring

# 3. 验证服务可访问
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# 访问 http://localhost:3000
```

---

## 常用排查命令

```bash
# 查看 Pod 状态
kubectl get pods -n monitoring

# 查看 Service
kubectl get svc -n monitoring

# 查看 Pod 日志
kubectl logs <pod-name> -n monitoring

# 查看 Pod 事件
kubectl describe pod <pod-name> -n monitoring

# 查看节点架构
kubectl get nodes -o wide

# 查看镜像架构
docker inspect <image> | grep Architecture

# 重启 Pod
kubectl delete pod <pod-name> -n monitoring

# 重启 Deployment
kubectl rollout restart deployment <deployment-name> -n monitoring

# 查看 Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# 然后访问 http://localhost:9090/targets
```

---

## 相关文档

- [README.md](./README.md) - 监控系统部署指南
- [DESIGN.md](./DESIGN.md) - 详细设计方案
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
