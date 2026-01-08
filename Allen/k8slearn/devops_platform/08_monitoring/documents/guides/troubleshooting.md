# 故障排查指南

> 🔧 监控系统常见问题排查手册

## 一、Prometheus 问题

### 1.1 Target 显示 DOWN

**症状**：Prometheus Targets 页面显示某个目标为 DOWN

**排查步骤**：

```bash
# 1. 检查目标 Pod 是否运行
kubectl get pods -n <namespace> -l <label>

# 2. 检查 Service 是否存在
kubectl get svc -n <namespace> <service-name>

# 3. 检查端口是否正确
kubectl get svc -n <namespace> <service-name> -o yaml | grep -A10 ports

# 4. 测试指标端点是否可访问
kubectl port-forward -n <namespace> svc/<service-name> 9090:9090
curl http://localhost:9090/metrics

# 5. 检查网络策略
kubectl get networkpolicy -n <namespace>

# 6. 从 Prometheus Pod 测试连接
kubectl exec -n monitoring <prometheus-pod> -- curl http://<service>.<namespace>.svc:9090/metrics
```

**常见原因**：
- Pod 未运行或不健康
- Service 配置错误
- 网络策略阻止访问
- 指标端点路径错误

---

### 1.2 ServiceMonitor 不生效

**症状**：创建了 ServiceMonitor 但 Target 没有出现

**排查步骤**：

```bash
# 1. 检查 ServiceMonitor 标签
kubectl get servicemonitor -n monitoring <name> -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 2. 检查 Prometheus 的 serviceMonitorSelector
kubectl get prometheus -n monitoring -o yaml | grep -A10 serviceMonitorSelector

# 3. 检查 ServiceMonitor 的 selector 是否匹配 Service
kubectl get svc -n <namespace> -l <label>

# 4. 检查 Prometheus Operator 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator --tail=100

# 5. 检查 Prometheus 配置是否更新
kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep <service-name>
```

**常见原因**：
- 缺少 `release: prometheus` 标签
- selector 不匹配 Service 标签
- namespaceSelector 配置错误
- 端口名称不匹配

---

### 1.3 指标数据缺失

**症状**：某些指标查询不到数据

**排查步骤**：

```bash
# 1. 检查指标是否存在
curl "http://182.42.82.135:30909/api/v1/label/__name__/values" | grep <metric_name>

# 2. 检查指标的标签
curl "http://182.42.82.135:30909/api/v1/series?match[]={__name__=\"<metric_name>\"}"

# 3. 检查 Exporter 是否暴露该指标
kubectl port-forward -n <namespace> <pod> 9090:9090
curl http://localhost:9090/metrics | grep <metric_name>

# 4. 检查数据保留时间
kubectl get prometheus -n monitoring -o yaml | grep retention
```

**常见原因**：
- Exporter 未暴露该指标
- 指标名称拼写错误
- 数据已过期被删除
- 标签过滤条件错误

---

### 1.4 Prometheus 内存/CPU 过高

**症状**：Prometheus Pod 资源使用过高

**排查步骤**：

```bash
# 1. 检查时间序列数量
curl http://182.42.82.135:30909/api/v1/status/tsdb | python3 -m json.tool

# 2. 检查抓取目标数量
curl http://182.42.82.135:30909/api/v1/targets | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Active targets: {len(data['data']['activeTargets'])}\")"

# 3. 检查高基数指标
curl http://182.42.82.135:30909/api/v1/status/tsdb | python3 -c "
import sys, json
data = json.load(sys.stdin)
for series in sorted(data['data']['seriesCountByMetricName'], key=lambda x: x['value'], reverse=True)[:10]:
    print(f\"{series['name']}: {series['value']}\")"
```

**解决方案**：
- 减少抓取目标
- 增加抓取间隔
- 减少数据保留时间
- 删除高基数指标
- 增加资源限制

---

## 二、AlertManager 问题

### 2.1 告警规则不生效

**症状**：创建了 PrometheusRule 但告警没有触发

**排查步骤**：

```bash
# 1. 检查 PrometheusRule 标签
kubectl get prometheusrule -n monitoring <name> -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 2. 检查 Prometheus 是否加载了规则
curl http://182.42.82.135:30909/api/v1/rules | grep <rule_name>

# 3. 在 Prometheus UI 测试表达式
# 访问 http://182.42.82.135:30909/graph
# 输入 expr 表达式，查看是否有结果

# 4. 检查告警状态
# 访问 http://182.42.82.135:30909/alerts
```

**常见原因**：
- 缺少 `release: prometheus` 标签
- PromQL 表达式错误
- `for` 时间还没到
- 表达式返回空结果

---

### 2.2 告警触发但没收到通知

**症状**：Prometheus 显示告警 firing，但没收到通知

**排查步骤**：

```bash
# 1. 检查 AlertManager 是否收到告警
curl http://182.42.82.135:30903/api/v2/alerts | python3 -m json.tool

# 2. 检查是否被静默
curl http://182.42.82.135:30903/api/v2/silences | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data:
    if s['status']['state'] == 'active':
        print(f\"Active silence: {s['comment']}\")"

# 3. 检查路由配置
kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# 4. 检查 Receiver 配置
# 确认 webhook URL 是否正确

# 5. 测试 Webhook 是否可达
curl -X POST http://<webhook-url> -d '{"test": "message"}'

# 6. 检查 AlertManager 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100
```

**常见原因**：
- 告警被静默
- 路由配置错误
- Webhook URL 不可达
- Receiver 配置错误

---

### 2.3 告警风暴

**症状**：收到大量重复告警

**解决方案**：

```yaml
# 1. 增加 for 时间
for: 5m  # 避免瞬时抖动

# 2. 调整 group_wait
route:
  group_wait: 30s  # 等待更多告警聚合

# 3. 增加 repeat_interval
route:
  repeat_interval: 4h  # 减少重复发送

# 4. 添加抑制规则
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace']

# 5. 创建静默规则
# 临时屏蔽已知问题
```

---

## 三、Grafana 问题

### 3.1 Dashboard 显示 No Data

**症状**：Grafana Panel 显示 No Data

**排查步骤**：

1. **检查数据源**：
   - Settings → Data Sources → Prometheus
   - 点击 `Test` 验证连接

2. **检查时间范围**：
   - 确认时间范围内有数据
   - 尝试扩大时间范围

3. **检查 PromQL**：
   - 在 Prometheus UI 测试相同的查询
   - 检查指标名称和标签是否正确

4. **检查变量**：
   - 如果使用了变量，确认变量有值
   - 检查变量的正则表达式

---

### 3.2 Grafana 无法登录

**症状**：忘记密码或无法登录

**解决方案**：

```bash
# 重置管理员密码
kubectl exec -n monitoring <grafana-pod> -- grafana-cli admin reset-admin-password newpassword

# 或者通过环境变量设置
kubectl set env deployment/prometheus-grafana -n monitoring GF_SECURITY_ADMIN_PASSWORD=newpassword
```

---

### 3.3 Dashboard 加载慢

**症状**：Dashboard 加载时间很长

**解决方案**：

1. **减少 Panel 数量**：每个 Dashboard 不超过 20 个 Panel
2. **缩短时间范围**：避免查询过长时间的数据
3. **使用 `$__interval`**：自动调整聚合间隔
4. **优化 PromQL**：避免复杂的嵌套查询

---

## 四、常用诊断命令

### 4.1 检查所有监控组件状态

```bash
# 检查所有 Pod
kubectl get pods -n monitoring

# 检查所有 Service
kubectl get svc -n monitoring

# 检查所有 ServiceMonitor
kubectl get servicemonitor -n monitoring

# 检查所有 PrometheusRule
kubectl get prometheusrule -n monitoring

# 检查 CRD
kubectl get crd | grep monitoring
```

### 4.2 检查 Prometheus 状态

```bash
# 检查配置
curl http://182.42.82.135:30909/api/v1/status/config

# 检查运行时信息
curl http://182.42.82.135:30909/api/v1/status/runtimeinfo

# 检查 TSDB 状态
curl http://182.42.82.135:30909/api/v1/status/tsdb

# 检查所有 Target
curl http://182.42.82.135:30909/api/v1/targets

# 检查所有规则
curl http://182.42.82.135:30909/api/v1/rules

# 检查所有告警
curl http://182.42.82.135:30909/api/v1/alerts
```

### 4.3 检查 AlertManager 状态

```bash
# 检查所有告警
curl http://182.42.82.135:30903/api/v2/alerts

# 检查所有静默
curl http://182.42.82.135:30903/api/v2/silences

# 检查状态
curl http://182.42.82.135:30903/api/v2/status
```

### 4.4 查看日志

```bash
# Prometheus 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# AlertManager 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100

# Grafana 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# Prometheus Operator 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator --tail=100
```

---

## 五、紧急恢复

### 5.1 重启监控组件

```bash
# 重启 Prometheus
kubectl rollout restart statefulset -n monitoring prometheus-prometheus-kube-prometheus-prometheus

# 重启 AlertManager
kubectl rollout restart statefulset -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager

# 重启 Grafana
kubectl rollout restart deployment -n monitoring prometheus-grafana

# 重启 Prometheus Operator
kubectl rollout restart deployment -n monitoring prometheus-kube-prometheus-operator
```

### 5.2 重新安装

```bash
# 卸载
helm uninstall prometheus -n monitoring

# 重新安装
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

---

## 六、联系方式

如果以上方法都无法解决问题，请收集以下信息后寻求帮助：

1. 问题描述
2. 相关日志
3. 配置文件
4. 环境信息（K8s 版本、Helm 版本等）

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
