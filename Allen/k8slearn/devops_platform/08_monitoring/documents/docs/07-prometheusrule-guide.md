# 告警规则编写指南

> 📝 定义"什么情况下触发告警"的规则

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
监控系统采集了大量指标，但你不可能 24 小时盯着看
PrometheusRule 就是"自动哨兵"，帮你盯着指标
一旦超过阈值，自动触发告警
```

**一句话精华**：
```
PrometheusRule = PromQL 表达式 + 持续时间 + 告警信息
```

**适合谁学**：需要配置告警的运维/开发人员
**不适合谁**：只需要使用现有告警的用户

---

## 二、核心框架（知识骨架）

**告警规则组成**：

```yaml
alert: 告警名称              # 这个告警叫什么
expr: PromQL 表达式          # 什么条件触发
for: 持续时间                # 持续多久才真正告警
labels:                      # 告警标签（用于路由）
  severity: warning
annotations:                 # 告警描述（给人看的）
  summary: "简短描述"
  description: "详细描述"
```

**生活化比喻**：
```
就像你家的烟雾报警器：
- alert: 烟雾报警
- expr: smoke_level > 100    （烟雾浓度超过 100）
- for: 10s                   （持续 10 秒才报警，避免炒菜误报）
- labels: severity=critical  （紧急程度：严重）
- annotations: "厨房有烟"    （告诉你哪里有问题）
```

---

## 三、PrometheusRule 完整结构

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-alerting-rules           # 规则集名称
  namespace: monitoring             # 命名空间
  labels:
    release: prometheus             # ⚠️ 必须！Prometheus 通过这个标签发现
spec:
  groups:
    - name: my-rules                # 规则组名称
      interval: 30s                 # 评估间隔（可选，默认用全局配置）
      rules:
        - alert: MyAlert            # 告警规则
          expr: |
            my_metric > 100
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "指标过高"
            description: "{{ $labels.instance }} 的指标超过 100"
        
        - record: my:metric:rate5m  # 记录规则（预计算）
          expr: rate(my_metric[5m])
```

---

## 四、关键字段详解

### 4.1 alert（告警名称）

**命名规范**：
- 使用 PascalCase（大驼峰）
- 名称要有意义，能看出是什么问题
- 建议格式：`<组件><问题>`

**示例**：
```yaml
# ✅ 好的命名
alert: NodeHighCPUUsage
alert: PodCrashLoopBackOff
alert: TektonPipelineRunFailed

# ❌ 不好的命名
alert: Alert1
alert: cpu_high
alert: problem
```

### 4.2 expr（PromQL 表达式）

**核心原则**：
- 表达式返回非空结果 = 条件满足
- 表达式返回空结果 = 条件不满足

**常用模式**：

```yaml
# 模式 1: 简单阈值
expr: node_load1 > 10

# 模式 2: 百分比计算
expr: |
  (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85

# 模式 3: 速率计算
expr: |
  rate(http_requests_total{status="500"}[5m]) > 10

# 模式 4: 聚合计算
expr: |
  sum by(namespace) (kube_pod_status_phase{phase="Failed"}) > 0

# 模式 5: 缺失检测
expr: |
  absent(up{job="my-app"})

# 模式 6: 变化检测
expr: |
  changes(kube_pod_container_status_restarts_total[1h]) > 5
```

### 4.3 for（持续时间）

**作用**：避免瞬时抖动触发告警

**建议值**：

| 场景 | 建议 for 值 | 说明 |
|------|------------|------|
| 紧急问题（服务宕机） | 1m | 快速响应 |
| 资源告警（CPU/内存） | 5m | 避免瞬时波动 |
| 趋势告警（磁盘增长） | 15m | 确认趋势 |
| 业务告警（错误率） | 2-5m | 平衡响应和准确 |

**常见误区**：
```yaml
# ❌ for 太短，容易误报
for: 10s

# ❌ for 太长，响应太慢
for: 1h

# ✅ 合理的 for 值
for: 5m
```

### 4.4 labels（标签）

**常用标签**：

| 标签 | 作用 | 常用值 |
|------|------|--------|
| `severity` | 告警级别 | critical, warning, info |
| `component` | 组件 | node, pod, network |
| `team` | 负责团队 | platform, devops, dev |

**示例**：
```yaml
labels:
  severity: warning
  component: node
  team: platform
```

### 4.5 annotations（注解）

**常用注解**：

| 注解 | 作用 | 说明 |
|------|------|------|
| `summary` | 简短描述 | 显示在告警列表 |
| `description` | 详细描述 | 显示在告警详情 |
| `runbook_url` | 处理手册 | 链接到处理文档 |

**模板变量**：

```yaml
annotations:
  summary: "节点 CPU 使用率过高"
  description: |
    节点 {{ $labels.instance }} CPU 使用率超过 80%
    当前值: {{ $value | printf "%.1f" }}%
    命名空间: {{ $labels.namespace }}
```

**可用变量**：
- `{{ $labels.xxx }}`：告警标签值
- `{{ $value }}`：表达式计算结果
- `{{ $value | printf "%.1f" }}`：格式化数值

---

## 五、实战示例

### 5.1 节点告警规则

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
```

### 5.2 Pod 告警规则

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
```

### 5.3 CI/CD 告警规则

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
        # Tekton Pipeline 失败
        - alert: TektonPipelineRunFailed
          expr: |
            tekton_pipelinerun_count{status="failed"} > 0
          for: 1m
          labels:
            severity: critical
            component: tekton
          annotations:
            summary: "Tekton Pipeline 执行失败"
            description: "Pipeline {{ $labels.pipeline }} 执行失败"
        
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
```

---

## 六、最佳实践

### 6.1 告警级别定义

| 级别 | 含义 | 响应时间 | 示例 |
|------|------|---------|------|
| `critical` | 严重，需立即处理 | 5 分钟内 | 服务宕机、数据丢失 |
| `warning` | 警告，需要关注 | 1 小时内 | 资源使用率高 |
| `info` | 信息，仅供参考 | 工作时间 | 配置变更 |

### 6.2 告警规则检查清单

- [ ] 有 `release: prometheus` 标签
- [ ] `for` 时间合理（不太短也不太长）
- [ ] `severity` 级别正确
- [ ] `annotations` 包含足够信息
- [ ] PromQL 表达式经过测试
- [ ] 告警名称有意义

### 6.3 避免告警风暴

```yaml
# 1. 设置合理的 for 时间
for: 5m  # 不要太短

# 2. 使用聚合减少告警数量
expr: |
  sum by(namespace) (kube_pod_status_phase{phase="Failed"}) > 0

# 3. 设置合理的阈值
expr: |
  cpu_usage > 80  # 不要设置太低的阈值
```

---

## 七、常用命令

```bash
# 创建/更新告警规则
kubectl apply -f my-alerting-rules.yaml

# 查看所有告警规则
kubectl get prometheusrule -n monitoring

# 查看规则详情
kubectl describe prometheusrule my-rules -n monitoring

# 删除告警规则
kubectl delete prometheusrule my-rules -n monitoring

# 验证规则是否被 Prometheus 加载
curl http://182.42.82.135:30909/api/v1/rules | python3 -m json.tool
```

---

## 八、常见问题

### Q1: 规则创建了但没生效

```bash
# 检查标签
kubectl get prometheusrule my-rules -n monitoring -o yaml | grep -A5 labels
# 必须有 release: prometheus
```

### Q2: PromQL 表达式不确定对不对

```bash
# 在 Prometheus UI 测试
# 访问 http://182.42.82.135:30909/graph
# 输入表达式，查看结果
```

### Q3: 告警一直 pending 不触发

```bash
# 检查 for 时间是否太长
# 检查表达式是否持续返回结果
```

---

## 九、金句收藏

```
"好的告警规则：该响的时候响，不该响的时候静"

"告警不是越多越好，而是越准越好"

"写告警规则前，先问自己：收到这个告警后，我要做什么？"
```

---

## 十、延伸资源

- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [PromQL 查询语言](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- 操作指南：[创建告警规则](../guides/create-alert-rule.md)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- 适用环境：Prometheus Operator / kube-prometheus-stack
