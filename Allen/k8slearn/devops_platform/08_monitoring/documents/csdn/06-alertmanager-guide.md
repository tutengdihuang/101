# AlertManager 告警系统：监控的"智能管家"

> 🎯 **一句话精华**：Prometheus 负责"发现问题"，AlertManager 负责"通知人"——它就是监控系统的"智能管家"，发现问题后打电话叫醒你！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
监控系统光采集数据不够，还需要在出问题时主动通知你！

想象一下：
- 凌晨 3 点，服务器 CPU 飙到 100%
- 你在睡觉，完全不知道
- 第二天早上，老板问你："昨晚服务挂了 4 小时，你知道吗？"
- 你：😱

有了 AlertManager：
- 凌晨 3 点，CPU 超过阈值
- AlertManager 立刻发送告警到你的手机
- 你被叫醒，5 分钟内解决问题
- 第二天早上，老板说："干得漂亮！"
- 你：😎
```

**适合谁学**：DevOps 工程师、SRE、运维人员
**不适合谁**：只需要看 Dashboard 的普通用户

---

## 二、开场故事：医院的急诊分诊台

> 想象你是医院急诊室的分诊护士：
> 
> 🚑 救护车送来一个病人（告警触发）
> 
> 你需要做什么？
> 1. **判断紧急程度**：心脏病还是感冒？（告警级别）
> 2. **避免重复挂号**：同一个病人不用挂两次号（去重）
> 3. **通知对应医生**：心脏病找心内科，骨折找骨科（路由）
> 4. **合并相关病人**：一家三口都感冒，一起看（分组）
> 5. **特殊情况处理**：VIP 病人走绿色通道（静默/抑制）
> 
> AlertManager 就是监控系统的"分诊台"！

---

## 三、核心概念速查表

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| PrometheusRule | 告警规则定义 | 温度计的阈值 | "超过 30°C 就报警" |
| AlertManager | 告警管理器 | 智能管家 | 收到报警后决定通知谁 |
| Receiver | 通知接收器 | 电话号码本 | Webhook/邮件/钉钉 |
| Route | 路由规则 | 分诊台 | 不同告警发给不同人 |
| Silence | 静默规则 | 免打扰模式 | 维护期间不发告警 |
| Inhibition | 抑制规则 | 智能过滤 | 根因告警抑制衍生告警 |
| Grouping | 分组 | 合并快递 | 相关告警合并发送 |

---

## 四、告警流程全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                    告警流程全景图                                │
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ 指标采集  │───▶│ 规则评估  │───▶│ 触发告警  │───▶│AlertManager│ │
│  │Prometheus│    │PromRule  │    │ firing   │    │  处理     │  │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘  │
│                                                       │         │
│                                                       ▼         │
│                                    ┌─────────────────────────┐  │
│                                    │    AlertManager 处理    │  │
│                                    │  ┌─────┐ ┌─────┐ ┌────┐│  │
│                                    │  │分组 │→│去重 │→│静默││  │
│                                    │  └─────┘ └─────┘ └────┘│  │
│                                    │         ↓              │  │
│                                    │  ┌─────┐ ┌─────────┐   │  │
│                                    │  │抑制 │→│路由匹配 │   │  │
│                                    │  └─────┘ └─────────┘   │  │
│                                    └───────────┬─────────────┘  │
│                                                │                │
│                                                ▼                │
│                                    ┌─────────────────────────┐  │
│                                    │      发送通知           │  │
│                                    │ Webhook/邮件/钉钉/微信  │  │
│                                    └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 五、告警状态流转

```
┌──────────┐    expr=true     ┌──────────┐    for 时间到     ┌──────────┐
│ inactive │ ───────────────▶ │ pending  │ ───────────────▶ │ firing   │
│  (正常)  │                  │ (等待中) │                  │ (触发中) │
└──────────┘                  └──────────┘                  └──────────┘
     ▲                              │                            │
     │ expr=false                   │ expr=false                 │ expr=false
     │                              ▼                            ▼
     └──────────────────────────────┴───────────────────── ┌──────────┐
                                                           │ resolved │
                                                           │ (已恢复) │
                                                           └──────────┘
```

**状态说明**：

| 状态 | 含义 | 触发条件 | UI 颜色 |
|------|------|---------|---------|
| `inactive` | 正常 | expr 返回 false | 绿色 |
| `pending` | 等待确认 | expr=true，未达到 for 时间 | 黄色 |
| `firing` | 触发中 | expr=true，达到 for 时间 | 红色 |
| `resolved` | 已恢复 | 之前 firing，现在 expr=false | 绿色 |

---

## 六、AlertManager 四大功能

### 6.1 分组 (Grouping)

**一句话是什么**：把相关的告警合并成一条消息发送

**生活化比喻**：
```
想象你是快递站管理员：
- 10 个包裹都发往"北京朝阳区"
- 你不会打 10 个电话通知快递员
- 而是合并成一条："有 10 个包裹发往北京朝阳区"
```

**配置示例**：

```yaml
route:
  group_by: ['alertname', 'namespace']  # 按告警名和命名空间分组
  group_wait: 30s      # 等待 30s 收集同组告警
  group_interval: 5m   # 同组告警发送间隔
```

**效果对比**：
```
场景: 10 个 Pod 同时 OOM

没有分组: 发送 10 条消息 😱
有分组:   发送 1 条消息（包含 10 个 Pod 信息）✅
```

### 6.2 去重 (Deduplication)

**一句话是什么**：同一个告警在一段时间内只发送一次

**配置示例**：

```yaml
route:
  repeat_interval: 4h  # 同一告警 4 小时内不重复发送
```

**效果对比**：
```
场景: CPU 持续过高 8 小时

没有去重: 每分钟发一条，共 480 条 😱
有去重:   第 0 小时发 1 条，第 4 小时发 1 条，共 2 条 ✅
```

### 6.3 静默 (Silence)

**一句话是什么**：临时屏蔽某些告警，用于维护期间

**使用场景**：
- 计划内维护
- 已知问题正在处理中
- 测试环境不需要告警

**创建方式**：

```bash
# 通过 API 创建静默
curl -X POST http://<alertmanager-ip>:<port>/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "NodeHighCPUUsage", "isRegex": false}
    ],
    "startsAt": "2026-01-05T10:00:00Z",
    "endsAt": "2026-01-05T12:00:00Z",
    "createdBy": "admin",
    "comment": "节点维护"
  }'
```

### 6.4 抑制 (Inhibition)

**一句话是什么**：当某个告警触发时，自动抑制相关的其他告警

**生活化比喻**：
```
停电了，你不需要收到这些告警：
- "冰箱温度升高"
- "空调停止工作"
- "电视无信号"

因为根因是"停电"，其他都是衍生问题
```

**配置示例**：

```yaml
inhibit_rules:
  # 当节点宕机时，抑制该节点上的所有 Pod 告警
  - source_match:
      alertname: 'NodeDown'
    target_match_re:
      alertname: 'Pod.*'
    equal: ['node']
  
  # 当 critical 告警触发时，抑制同实例的 warning 告警
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace', 'instance']
```

---

## 七、路由规则 (Route)

**一句话是什么**：决定不同的告警发送到哪个接收器

**生活化比喻**：
```
医院的分诊台：
- 心脏病 → 心内科
- 骨折   → 骨科
- 感冒   → 普通门诊

告警的分诊台：
- severity=critical → 立即电话通知
- severity=warning  → 发送到钉钉群
- alertname=Tekton* → 发送到 CI/CD 群
```

**配置示例**：

```yaml
route:
  # 默认接收器
  receiver: 'default-receiver'
  group_by: ['alertname', 'namespace']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  
  # 子路由（按顺序匹配）
  routes:
    # Critical 告警：立即通知
    - match:
        severity: critical
      receiver: 'critical-receiver'
      group_wait: 10s
      repeat_interval: 1h
    
    # Warning 告警：普通通知
    - match:
        severity: warning
      receiver: 'warning-receiver'
      repeat_interval: 4h

receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook'
        send_resolved: true
  
  - name: 'critical-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook/critical'
```

---

## 八、告警规则示例

### 8.1 节点告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus  # ⚠️ 必须！
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
          annotations:
            summary: "节点 CPU 使用率过高"
            description: "节点 {{ $labels.instance }} CPU 使用率超过 80%"
        
        # 内存使用率过高
        - alert: NodeHighMemoryUsage
          expr: |
            (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "节点内存使用率过高"
            description: "节点 {{ $labels.instance }} 内存使用率超过 85%"
```

### 8.2 Pod 告警

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
          annotations:
            summary: "Pod 处于 CrashLoopBackOff 状态"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 处于崩溃循环"
        
        # Pod OOM
        - alert: PodOOMKilled
          expr: |
            kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Pod 因 OOM 被终止"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 因内存不足被终止"
```

---

## 九、告警级别定义

| 级别 | 含义 | 响应时间 | 示例 |
|------|------|---------|------|
| `critical` | 严重，需立即处理 | 5 分钟内 | 服务宕机、OOM |
| `warning` | 警告，需要关注 | 1 小时内 | 资源使用率高 |
| `info` | 信息，仅供参考 | 工作时间 | 配置变更 |

---

## 十、常见问题

### Q1: 告警规则不生效

**检查清单**：
```bash
# 1. 检查 PrometheusRule 标签
kubectl get prometheusrule my-rules -n monitoring -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 2. 检查 Prometheus 是否加载了规则
# 访问 Prometheus UI → Status → Rules

# 3. 在 Prometheus UI 测试表达式
# 访问 Prometheus UI → Graph → 输入 expr
```

### Q2: 告警触发但没收到通知

**检查清单**：
```bash
# 1. 检查 AlertManager 是否收到告警
# 访问 AlertManager UI → Alerts

# 2. 检查是否被静默
# 访问 AlertManager UI → Silences

# 3. 检查 Webhook URL 是否可达
curl -X POST http://your-webhook-url -d '{"test": "message"}'
```

### Q3: 告警风暴

**解决方案**：
1. 增加 `for` 时间（避免瞬时抖动）
2. 调整 `group_wait`（等待更多告警聚合）
3. 增加 `repeat_interval`（减少重复发送）
4. 添加抑制规则（抑制衍生告警）

---

## 十一、金句收藏

```
"Prometheus 是发现问题的眼睛，AlertManager 是通知问题的嘴巴"

"好的告警系统：该响的时候响，不该响的时候静"

"告警不是越多越好，而是越准越好"

"写告警规则前，先问自己：收到这个告警后，我要做什么？"
```

---

## 十二、学习检查清单

- [ ] 理解告警状态流转（inactive → pending → firing → resolved）
- [ ] 理解 AlertManager 四大功能（分组、去重、静默、抑制）
- [ ] 能创建基本的 PrometheusRule
- [ ] 能配置路由规则
- [ ] 能创建静默规则

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- AlertManager 版本：v0.27.0

---

> 📝 **下一篇**：[告警规则编写指南](07-prometheusrule-guide.md) - 学习如何编写告警规则
