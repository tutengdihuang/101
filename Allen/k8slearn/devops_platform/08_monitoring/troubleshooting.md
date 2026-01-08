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

## 问题 8: ArgoCD Metrics 无法被 Prometheus 收集

### 症状

ArgoCD targets 在 Prometheus 中显示为 dropped 状态，无法收集 metrics

```bash
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- "http://localhost:9090/api/v1/targets" | grep -o '"droppedTargetCounts"' | wc -l
```

输出示例:
```
droppedTargetCounts":{"serviceMonitor/monitoring/argocd-application-controller-servicemonitor/0":6,"serviceMonitor/monitoring/argocd-repo-server-servicemonitor/0":6}
```

### 问题分析

1. **argocd-server** 在端口 8083 上暴露了 metrics，但：
   - Deployment 中的端口没有命名
   - Service 中没有定义 metrics 端口
   - 没有为 argocd-server 创建 ServiceMonitor

2. **ServiceMonitor 配置问题**：
   - argocd-application-controller-servicemonitor 使用了端口号 "8082" 而非端口名称
   - Prometheus Operator 要求 ServiceMonitor 使用端口名称而非端口号

### 排查步骤

```bash
# 1. 查看 ArgoCD Pods
kubectl get pods -n argocd

# 2. 查看 ArgoCD Services
kubectl get svc -n argocd

# 3. 查看 ServiceMonitor 配置
kubectl get servicemonitor -n monitoring | grep argocd

# 4. 查看 Prometheus targets
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- "http://localhost:9090/api/v1/targets" | python3 -c "import sys, json; data = json.load(sys.stdin); [print(f\"Job: {t['labels']['job']}, Health: {t['health']}\") for t in data['data']['activeTargets'] if 'argocd' in t['labels']['job'].lower()]"

# 5. 直接访问 metrics 端点验证
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- --timeout=10 "http://<argocd-server-pod-ip>:8083/metrics" | head -20
```

### 解决方案

#### 步骤 1: 修改 argocd-server Deployment

给 argocd-server Deployment 的端口 8083 添加名称 "metrics"

修改文件: [argocd-components.yaml](../../04_argocd/install/argocd-components.yaml)

```yaml
# ArgoCD Server Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      containers:
      - name: argocd-server
        image: quay.io/argoproj/argocd:v2.9.3
        ports:
        - containerPort: 8080
        - containerPort: 8083
          name: metrics  # 添加端口名称
```

#### 步骤 2: 修改 argocd-server Service

给 argocd-server Service 添加 metrics 端口和标签

修改文件: [argocd-components.yaml](../../04_argocd/install/argocd-components.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server  # 添加标签
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 30090
  - name: https
    port: 443
    targetPort: 8080
    nodePort: 30091
  - name: metrics  # 添加 metrics 端口
    port: 8083
    targetPort: 8083
  selector:
    app.kubernetes.io/name: argocd-server
```

#### 步骤 3: 修改 ArgoCD ServiceMonitor

修改 argocd-application-controller-servicemonitor 使用端口名称而非端口号

修改文件: [argocd-servicemonitor.yaml](./servicemonitors/argocd-servicemonitor.yaml)

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
    - port: metrics  # 使用端口名称而非端口号 "8082"
      interval: 30s
      path: /metrics
```

#### 步骤 4: 添加 argocd-server ServiceMonitor

为 argocd-server 创建新的 ServiceMonitor

修改文件: [argocd-servicemonitor.yaml](./servicemonitors/argocd-servicemonitor.yaml)

```yaml
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

#### 步骤 5: 应用修改

```bash
# 1. 应用 ArgoCD 组件修改
kubectl apply -f /path/to/argocd-components.yaml

# 2. 应用 ServiceMonitor 修改
kubectl apply -f /path/to/argocd-servicemonitor.yaml

# 3. 等待 Pod 重启
kubectl rollout status deployment/argocd-server -n argocd
```

### 验证结果

等待 15-30 秒让 Prometheus 重新发现 targets

```bash
# 1. 验证 ArgoCD targets 状态
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- "http://localhost:9090/api/v1/targets" | python3 -c "import sys, json; data = json.load(sys.stdin); [print(f\"Job: {t['labels']['job']}, Health: {t['health']}, Instance: {t['labels']['instance']}\") for t in data['data']['activeTargets'] if 'argocd' in t['labels']['job'].lower()]"
```

预期输出:
```
Job: argocd-application-controller, Health: up, Instance: 10.244.194.119:8082
Job: argocd-repo-server, Health: up, Instance: 10.244.194.101:8084
Job: argocd-server, Health: up, Instance: 10.244.194.124:8083
```

```bash
# 2. 验证指标数据
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- "http://localhost:9090/api/v1/query?query=up{job=~\".*argocd.*\"}" | python3 -c "import sys, json; data = json.load(sys.stdin); [print(f\"{r['metric']['job']}: {r['value'][1]}\") for r in data['data']['result']]"
```

预期输出:
```
argocd-application-controller: 1
argocd-repo-server: 1
argocd-server: 1
```

```bash
# 3. 验证指标数量
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- "http://localhost:9090/api/v1/query?query={job=\"argocd-server\"}" | python3 -c "import sys, json; data = json.load(sys.stdin); print(f\"Total metrics from argocd-server: {len(data['data']['result'])}\")"
```

预期输出:
```
Total metrics from argocd-server: 1886
```

### 关键要点

1. **端口名称 vs 端口号**：ServiceMonitor 必须使用端口名称而非端口号
2. **标签匹配**：Service 的标签必须与 ServiceMonitor 的 selector 匹配
3. **端口定义**：Service 必须定义与 Pod 中端口名称匹配的端口
4. **本地文件优先**：按照项目规则，先修改本地文件，然后上传到服务器

### 修改的文件

| 文件 | 修改内容 |
|------|---------|
| [argocd-components.yaml](../../04_argocd/install/argocd-components.yaml) | argocd-server Deployment 端口命名、Service 添加 metrics 端口和标签 |
| [argocd-servicemonitor.yaml](./servicemonitors/argocd-servicemonitor.yaml) | 修改使用端口名称、添加 argocd-server ServiceMonitor |

---

## 问题 9: AlertManager 镜像拉取失败

### 症状

AlertManager Pod 状态为 ImagePullBackOff

```bash
kubectl get pods -n monitoring | grep alertmanager
```

输出示例:
```
alertmanager-prometheus-kube-prometheus-alertmanager-0   0/2     ImagePullBackOff   0          5m
```

### 原因

镜像路径配置错误，导致镜像路径重复

错误配置示例:
```yaml
global:
  imageRegistry: swr.cn-north-4.myhuaweicloud.com/ddn-k8s

alertmanager:
  alertmanagerSpec:
    image:
      registry: swr.cn-north-4.myhuaweicloud.com
      repository: ddn-k8s/quay.io/prometheus/alertmanager
      tag: v0.27.0
```

实际镜像路径变成: `swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ddn-k8s/quay.io/prometheus/alertmanager:v0.27.0`

### 排查步骤

```bash
# 1. 查看 Pod 状态
kubectl get pods -n monitoring | grep alertmanager

# 2. 查看 Pod 详情
kubectl describe pod alertmanager-prometheus-kube-prometheus-alertmanager-0 -n monitoring

# 3. 查看镜像路径
kubectl get pod alertmanager-prometheus-kube-prometheus-alertmanager-0 -n monitoring -o jsonpath='{.spec.containers[*].image}'
```

### 解决方案

移除 `global.imageRegistry` 配置，直接在组件中配置完整镜像路径

修改文件: [values.yaml](./install/values.yaml)

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

重新部署:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

### 验证结果

```bash
# 1. 验证 Pod 状态
kubectl get pods -n monitoring | grep alertmanager
```

预期输出:
```
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          5m
```

```bash
# 2. 验证镜像路径
kubectl get pod alertmanager-prometheus-kube-prometheus-alertmanager-0 -n monitoring -o jsonpath='{.spec.containers[*].image}'
```

预期输出:
```
swr.cn-north-4.myhuaweicloud.com/ddn-k8s/quay.io/prometheus/alertmanager:v0.27.0
```

---

## 问题 10: CI/CD 告警规则未被 Prometheus 加载

### 症状

创建 PrometheusRule 资源后，Prometheus API 中未显示对应的告警规则组

```bash
curl -s http://<prometheus-url>:30909/api/v1/rules | python3 -m json.tool | grep -E "(tekton|argocd)"
```

输出示例:
```
(无输出，表示未找到 tekton 或 argocd 规则组)
```

### 可能原因

1. PrometheusRule 资源未正确创建
2. 标签不匹配（Prometheus 的 ruleSelector 不匹配 PrometheusRule 的标签）
3. 命名空间不匹配（Prometheus 的 ruleNamespaceSelector 不匹配）

### 排查步骤

```bash
# 1. 验证 PrometheusRule 资源是否存在
kubectl get prometheusrules -n monitoring | grep -E "(cicd|infrastructure)"

# 2. 查看 PrometheusRule 标签
kubectl get prometheusrules cicd-alerting-rules -n monitoring -o yaml | grep -A 5 labels:

# 3. 查看 Prometheus 配置
kubectl get prometheus prometheus-kube-prometheus-prometheus -n monitoring -o yaml | grep -A 10 ruleSelector

# 4. 查看 Prometheus 日志
kubectl logs prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring -c prometheus --tail=50
```

### 解决方案

确保 PrometheusRule 资源具有正确的标签，与 Prometheus 的 ruleSelector 匹配

修改文件: [cicd-alerting-rules.yaml](./install/cicd-alerting-rules.yaml)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cicd-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus  # 必须与 Prometheus 的 ruleSelector 匹配
spec:
  groups:
    - name: tekton.rules
      rules:
        - alert: TektonPipelineRunFailed
          expr: |
            increase(tekton_pipelines_controller_pipelinerun_count{status="failed"}[5m]) > 0
          for: 1m
          labels:
            severity: critical
            component: tekton
          annotations:
            summary: "Tekton PipelineRun 失败"
            description: "命名空间 {{ $labels.namespace }} 中有 PipelineRun 执行失败"
```

修改文件: [infrastructure-alerting-rules.yaml](./install/infrastructure-alerting-rules.yaml)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: infrastructure-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus  # 必须与 Prometheus 的 ruleSelector 匹配
spec:
  groups:
    - name: node.rules
      rules:
        - alert: NodeHighCPUUsage
          expr: |
            100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
          for: 5m
          labels:
            severity: warning
            component: node
          annotations:
            summary: "节点 CPU 使用率过高"
            description: "节点 {{ $labels.instance }} CPU 使用率超过 80%，当前值: {{ $value | printf \"%.1f\" }}%"
```

应用修改:

```bash
kubectl apply -f cicd-alerting-rules.yaml
kubectl apply -f infrastructure-alerting-rules.yaml
```

### 验证结果

等待 30 秒让 Prometheus 重新加载规则

```bash
# 1. 验证 PrometheusRule 资源
kubectl get prometheusrules -n monitoring | grep -E "(cicd|infrastructure)"
```

预期输出:
```
cicd-alerting-rules                                               5m
infrastructure-alerting-rules                                     5m
```

```bash
# 2. 验证规则已加载
curl -s http://<prometheus-url>:30909/api/v1/rules | python3 -m json.tool | grep -E '"name": "(tekton|argocd|node|pod)\.rules"'
```

预期输出:
```
"name": "tekton.rules"
"name": "argocd.rules"
"name": "node.rules"
"name": "pod.rules"
```

```bash
# 3. 验证规则详情
curl -s http://<prometheus-url>:30909/api/v1/rules | python3 -m json.tool | grep -A 10 '"name": "tekton\.rules"'
```

预期输出:
```
{
    "name": "tekton.rules",
    "file": "/etc/prometheus/rules/.../monitoring-cicd-alerting-rules-...yaml",
    "rules": [
        {
            "state": "inactive",
            "name": "TektonPipelineRunFailed",
            ...
        },
        ...
    ]
}
```

---

## 问题 11: Prometheus 无法连接到 AlertManager

### 症状

Prometheus 日志显示连接 AlertManager 失败

```bash
kubectl logs prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring -c prometheus --tail=20 | grep -i alertmanager
```

输出示例:
```
Error sending alerts alertmanager=http://10.244.194.121:9093/api/v2/alerts count=1 err="Post \"http://10.244.194.121:9093/api/v2/alerts\": dial tcp 10.244.194.121:9093: connect: connection refused"
```

### 可能原因

1. AlertManager Pod 未启动
2. AlertManager 服务端口未正确配置
3. 网络策略阻止连接

### 排查步骤

```bash
# 1. 查看 AlertManager Pod 状态
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# 2. 查看 AlertManager 服务
kubectl get svc -n monitoring | grep alertmanager

# 3. 查看 Prometheus alertmanagers 配置
curl -s http://<prometheus-url>:30909/api/v1/alertmanagers | python3 -m json.tool

# 4. 查看 AlertManager 日志
kubectl logs alertmanager-prometheus-kube-prometheus-alertmanager-0 -n monitoring -c alertmanager --tail=20
```

### 解决方案

确保 AlertManager Pod 正常运行，Prometheus 配置正确

```bash
# 1. 验证 AlertManager Pod 状态
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
```

预期输出:
```
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          10m
```

```bash
# 2. 验证 AlertManager 服务
kubectl get svc -n monitoring | grep alertmanager
```

预期输出:
```
prometheus-kube-prometheus-alertmanager   NodePort    10.100.182.49    <none>        9093:30903/TCP,8080:30902/TCP   10m
```

```bash
# 3. 验证 Prometheus alertmanagers 配置
curl -s http://<prometheus-url>:30909/api/v1/alertmanagers | python3 -m json.tool
```

预期输出:
```
{
    "status": "success",
    "data": {
        "activeAlertmanagers": [
            {
                "url": "http://10.244.194.125:9093/api/v2/alerts"
            }
        ],
        ...
    }
}
```

```bash
# 4. 验证 AlertManager 可访问
curl -s http://<alertmanager-url>:30903/api/v2/status | python3 -m json.tool | grep version
```

预期输出:
```
"version": "0.27.0"
```

### 验证告警发送

```bash
# 1. 查看 Prometheus 告警
curl -s http://<prometheus-url>:30909/api/v1/alerts | python3 -m json.tool | grep -E '"alertname"|"state"'

# 2. 查看 AlertManager 告警
curl -s http://<alertmanager-url>:30903/api/v2/alerts | python3 -m json.tool | grep -E '"alertname"|"state"'
```

---

## AlertManager 配置验证

### 配置文件

AlertManager 配置文件: [values.yaml](./install/values.yaml)

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
  
  config:
    global:
      resolve_timeout: 5m
    
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
    
    inhibit_rules:
      - source_match:
          severity: critical
        target_match:
          severity: warning
        equal: ['alertname', 'namespace', 'instance']
    
    receivers:
      - name: 'default-receiver'
        webhook_configs:
          - url: 'http://example.com/webhook'
            send_resolved: true
      
      - name: 'critical-receiver'
        webhook_configs:
          - url: 'http://example.com/critical'
            send_resolved: true
      
      - name: 'warning-receiver'
        webhook_configs:
          - url: 'http://example.com/warning'
            send_resolved: true
      
      - name: 'cicd-receiver'
        webhook_configs:
          - url: 'http://example.com/cicd'
            send_resolved: true
```

### 告警规则文件

CI/CD 告警规则: [cicd-alerting-rules.yaml](./install/cicd-alerting-rules.yaml)

基础设施告警规则: [infrastructure-alerting-rules.yaml](./install/infrastructure-alerting-rules.yaml)

### 验证步骤

```bash
# 1. 验证 AlertManager Pod 状态
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager

# 2. 验证 AlertManager 服务
kubectl get svc -n monitoring | grep alertmanager

# 3. 验证 PrometheusRule 资源
kubectl get prometheusrules -n monitoring

# 4. 验证 Prometheus 规则加载
curl -s http://<prometheus-url>:30909/api/v1/rules | python3 -m json.tool | grep '"name"'

# 5. 验证 Prometheus 与 AlertManager 连接
curl -s http://<prometheus-url>:30909/api/v1/alertmanagers | python3 -m json.tool

# 6. 验证 AlertManager 配置
curl -s http://<alertmanager-url>:30903/api/v2/status | python3 -m json.tool

# 7. 验证告警发送
curl -s http://<alertmanager-url>:30903/api/v2/alerts | python3 -m json.tool
```

### 访问地址

- Prometheus: http://182.42.82.135:30909
- AlertManager: http://182.42.82.135:30903
- Grafana: http://182.42.82.135:30300

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

# 查看 ServiceMonitor
kubectl get servicemonitor -n monitoring

# 查看 ServiceMonitor 详情
kubectl describe servicemonitor <name> -n monitoring

# 验证 metrics 端点
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- wget -qO- --timeout=10 "http://<pod-ip>:<port>/metrics"
```

---

## 相关文档

- [README.md](./README.md) - 监控系统部署指南
- [DESIGN.md](./DESIGN.md) - 详细设计方案
- [VERIFICATION.md](./VERIFICATION.md) - 验证文档
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
