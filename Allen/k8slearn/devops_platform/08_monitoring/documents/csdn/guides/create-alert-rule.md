# 创建告警规则：让系统主动告诉你出问题了

> 🎯 **一句话精华**：PrometheusRule = 告诉 Prometheus "什么情况下喊我"——就像设置闹钟，到点就响！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
你不可能 24 小时盯着监控大屏
告警规则就是你的"哨兵"
一旦发现异常，立刻通知你
```

**适合谁学**：需要配置自动告警的运维/开发人员
**不适合谁**：只看 Dashboard 不需要告警的用户

---

## 二、快速开始（5 分钟搞定）

### 2.1 创建告警规则文件

```yaml
# my-alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus              # ⚠️ 必须有这个标签！
spec:
  groups:
    - name: my-rules
      rules:
        - alert: MyFirstAlert
          expr: up == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "目标不可达"
            description: "{{ $labels.instance }} 已经不可达超过 5 分钟"
```

### 2.2 应用规则

```bash
kubectl apply -f my-alerting-rules.yaml
```

### 2.3 验证规则

```bash
# 检查 PrometheusRule 是否创建
kubectl get prometheusrule -n monitoring

# 检查 Prometheus 是否加载了规则
# 访问 http://<prometheus-ip>:<port>/rules

# 检查告警状态
# 访问 http://<prometheus-ip>:<port>/alerts
```

---

## 三、告警规则详解

### 3.1 规则结构

```yaml
- alert: AlertName           # 告警名称
  expr: <PromQL表达式>       # 触发条件
  for: 5m                    # 持续时间（避免抖动）
  labels:                    # 告警标签
    severity: critical       # 严重程度
  annotations:               # 告警描述
    summary: "简短描述"
    description: "详细描述"
```

**生活化比喻**：
```
告警规则就像设置闹钟：
- alert = 闹钟名称（起床闹钟）
- expr = 触发条件（时间到了）
- for = 响多久才算数（响 5 分钟才叫醒我）
- labels = 闹钟类型（紧急/普通）
- annotations = 闹钟备注（今天有重要会议）
```

### 3.2 告警级别定义

| 级别 | 含义 | 响应时间 | 示例 |
|------|------|---------|------|
| `critical` | 严重，需立即处理 | 5 分钟内 | 服务宕机、OOM |
| `warning` | 警告，需要关注 | 1 小时内 | 资源使用率高 |
| `info` | 信息，仅供参考 | 工作时间 | 配置变更 |

---

## 四、常用告警规则模板

### 4.1 节点告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: node.rules
      rules:
        # CPU 使用率过高
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
        
        # CPU 使用率严重过高
        - alert: NodeCriticalCPUUsage
          expr: |
            100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 95
          for: 5m
          labels:
            severity: critical
            component: node
          annotations:
            summary: "节点 CPU 使用率严重过高"
            description: "节点 {{ $labels.instance }} CPU 使用率超过 95%，当前值: {{ $value | printf \"%.1f\" }}%"
        
        # 内存使用率过高
        - alert: NodeHighMemoryUsage
          expr: |
            (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
          for: 5m
          labels:
            severity: warning
            component: node
          annotations:
            summary: "节点内存使用率过高"
            description: "节点 {{ $labels.instance }} 内存使用率超过 85%，当前值: {{ $value | printf \"%.1f\" }}%"
        
        # 磁盘使用率过高
        - alert: NodeHighDiskUsage
          expr: |
            (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 > 80
          for: 5m
          labels:
            severity: warning
            component: node
          annotations:
            summary: "节点磁盘使用率过高"
            description: "节点 {{ $labels.instance }} 磁盘使用率超过 80%"
        
        # 磁盘使用率严重过高
        - alert: NodeCriticalDiskUsage
          expr: |
            (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 > 90
          for: 5m
          labels:
            severity: critical
            component: node
          annotations:
            summary: "节点磁盘使用率严重过高"
            description: "节点 {{ $labels.instance }} 磁盘使用率超过 90%，请立即处理！"
```

### 4.2 Pod 告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: pod.rules
      rules:
        # Pod 崩溃循环
        - alert: PodCrashLoopBackOff
          expr: |
            kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
          for: 5m
          labels:
            severity: critical
            component: pod
          annotations:
            summary: "Pod 处于 CrashLoopBackOff 状态"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 容器 {{ $labels.container }} 处于崩溃循环"
        
        # Pod 频繁重启
        - alert: PodFrequentRestart
          expr: |
            increase(kube_pod_container_status_restarts_total[10m]) > 5
          for: 1m
          labels:
            severity: warning
            component: pod
          annotations:
            summary: "Pod 频繁重启"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 在 10 分钟内重启超过 5 次"
        
        # Pod OOM
        - alert: PodOOMKilled
          expr: |
            kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
          for: 1m
          labels:
            severity: critical
            component: pod
          annotations:
            summary: "Pod 因 OOM 被终止"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 容器 {{ $labels.container }} 因内存不足被终止"
        
        # Pod 内存使用率过高
        - alert: PodHighMemoryUsage
          expr: |
            container_memory_working_set_bytes{container!=""} 
            / on(namespace,pod,container) 
            kube_pod_container_resource_limits{resource="memory"} > 0.85
          for: 5m
          labels:
            severity: warning
            component: pod
          annotations:
            summary: "Pod 内存使用率过高"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 内存使用率超过 85%"
```

### 4.3 CI/CD 告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cicd-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: cicd.rules
      rules:
        # ArgoCD 应用未同步
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
        
        # ArgoCD 应用健康异常
        - alert: ArgoCDAppDegraded
          expr: |
            argocd_app_health_status{health_status="Degraded"} == 1
          for: 5m
          labels:
            severity: critical
            component: argocd
          annotations:
            summary: "ArgoCD 应用健康异常"
            description: "应用 {{ $labels.name }} 健康状态为 Degraded"
```

---

## 五、测试告警规则

### 5.1 在 Prometheus UI 测试表达式

1. 访问 `http://<prometheus-ip>:<port>/graph`
2. 输入 PromQL 表达式
3. 点击 Execute
4. 查看结果是否符合预期

### 5.2 模拟告警触发

```bash
# 方法 1: 调整阈值使其触发
# 例如：将 CPU 阈值从 80% 改为 10%

# 方法 2: 使用 absent() 测试
# expr: absent(up{job="non-existent-job"})
```

---

## 六、常用命令

```bash
# 创建/更新告警规则
kubectl apply -f my-alerting-rules.yaml

# 查看所有告警规则
kubectl get prometheusrule -n monitoring

# 查看规则详情
kubectl describe prometheusrule my-alerting-rules -n monitoring

# 删除告警规则
kubectl delete prometheusrule my-alerting-rules -n monitoring

# 查看 Prometheus 加载的规则（API）
curl -s http://<prometheus-ip>:<port>/api/v1/rules | python3 -m json.tool

# 查看当前触发的告警（API）
curl -s http://<alertmanager-ip>:<port>/api/v2/alerts | python3 -m json.tool
```

---

## 七、常见问题

### Q1: 规则创建了但没生效

```bash
# 检查标签
kubectl get prometheusrule my-rules -n monitoring -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 检查 Prometheus Operator 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator --tail=50
```

### Q2: 告警一直 pending 不触发

可能原因：
1. `for` 时间还没到
2. 表达式结果不稳定（时有时无）

解决方法：
1. 等待 `for` 时间
2. 检查表达式是否持续返回结果

### Q3: 告警触发但没收到通知

参考：[告警静默操作](silence-alerts.md) 检查是否被静默

---

## 八、最佳实践

### 8.1 告警规则检查清单

- [ ] 有 `release: prometheus` 标签
- [ ] `for` 时间合理（不太短也不太长）
- [ ] `severity` 级别正确
- [ ] `annotations` 包含足够信息
- [ ] PromQL 表达式经过测试

### 8.2 避免告警风暴

1. 设置合理的 `for` 时间（建议 5m）
2. 不要设置过低的阈值
3. 使用聚合减少告警数量

### 8.3 告警描述模板

```yaml
annotations:
  summary: "[{{ $labels.severity | toUpper }}] {{ $labels.alertname }}"
  description: |
    告警名称: {{ $labels.alertname }}
    命名空间: {{ $labels.namespace }}
    Pod: {{ $labels.pod }}
    当前值: {{ $value | printf "%.2f" }}
```

---

## 九、金句收藏

```
"告警三要素：表达式、持续时间、严重程度"

"for 时间太短 = 告警风暴，for 时间太长 = 错过问题"

"告警不是越多越好，而是越准越好"

"没有 release: prometheus 标签 = 规则不生效"
```

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：kube-prometheus-stack

---

> 📝 **系列导航**：
> - 上一篇：[添加监控目标](add-servicemonitor.md)
> - 下一篇：[创建 Grafana Dashboard](create-dashboard.md)
