# AlertManager 告警系统

> 🔔 监控系统的"智能管家"——发现问题后通知正确的人

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
监控系统光采集数据不够，还需要在出问题时主动通知你！
AlertManager 就是那个"发现问题后打电话给你"的管家。
```

**一句话精华**：
```
Prometheus 负责"发现问题"（评估规则）
AlertManager 负责"通知人"（发送告警）
```

**适合谁学**：DevOps 工程师、SRE、运维人员
**不适合谁**：只需要看 Dashboard 的普通用户

---

## 二、核心框架（知识骨架）

**关键概念速查表**：

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| PrometheusRule | 告警规则定义 | 温度计的阈值 | "超过 30°C 就报警" |
| AlertManager | 告警管理器 | 智能管家 | 收到报警后决定通知谁 |
| Receiver | 通知接收器 | 电话号码本 | Webhook/邮件/钉钉 |
| Route | 路由规则 | 分诊台 | 不同告警发给不同人 |
| Silence | 静默规则 | 免打扰模式 | 维护期间不发告警 |
| Inhibition | 抑制规则 | 智能过滤 | 根因告警抑制衍生告警 |
| Grouping | 分组 | 合并快递 | 相关告警合并发送 |

**告警流程全景图**：

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

## 三、告警状态流转

**状态流转图**：

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

## 四、AlertManager 四大功能

### 4.1 分组 (Grouping)

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

### 4.2 去重 (Deduplication)

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

### 4.3 静默 (Silence)

**一句话是什么**：临时屏蔽某些告警，用于维护期间

**使用场景**：
- 计划内维护
- 已知问题正在处理中
- 测试环境不需要告警

**创建方式**：

**方式 1: 通过 UI**
```
访问: http://182.42.82.135:30903/#/silences/new

填写:
- 匹配条件: alertname = "NodeHighCPUUsage"
- 开始时间: 2026-01-05 10:00
- 结束时间: 2026-01-05 12:00
- 原因: 节点维护，升级内核
- 创建者: zhangsan
```

**方式 2: 通过 API**
```bash
curl -X POST http://182.42.82.135:30903/api/v2/silences \
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

### 4.4 抑制 (Inhibition)

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

## 五、路由规则 (Route)

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
    
    # CI/CD 相关告警
    - match_re:
        alertname: ^(Tekton|ArgoCD).*
      receiver: 'cicd-receiver'
      group_by: ['alertname', 'namespace']

receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook'
        send_resolved: true
  
  - name: 'critical-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook/critical'
  
  - name: 'warning-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook/warning'
  
  - name: 'cicd-receiver'
    webhook_configs:
      - url: 'http://webhook-server:5001/webhook/cicd'
```

---

## 六、当前环境配置

### 6.1 访问地址

| 组件 | 地址 | 用途 |
|------|------|------|
| AlertManager UI | http://182.42.82.135:30903 | 查看告警、创建静默 |
| Prometheus Alerts | http://182.42.82.135:30909/alerts | 查看告警规则状态 |
| Prometheus Rules | http://182.42.82.135:30909/rules | 查看规则详情 |

### 6.2 已部署的告警规则

**CI/CD 告警**：

| 告警名 | 触发条件 | 持续时间 | 级别 |
|--------|---------|---------|------|
| `TektonPipelineRunFailed` | Pipeline 失败 | 1m | critical |
| `TektonPipelineRunTooLong` | Pipeline 运行超 30m | 30m | warning |
| `ArgoCDAppOutOfSync` | 应用未同步 | 10m | warning |
| `ArgoCDAppDegraded` | 应用健康异常 | 5m | critical |

**基础设施告警**：

| 告警名 | 触发条件 | 持续时间 | 级别 |
|--------|---------|---------|------|
| `NodeHighCPUUsage` | CPU > 80% | 5m | warning |
| `NodeCriticalCPUUsage` | CPU > 95% | 5m | critical |
| `NodeHighMemoryUsage` | 内存 > 85% | 5m | warning |
| `NodeHighDiskUsage` | 磁盘 > 80% | 5m | warning |
| `PodCrashLoopBackOff` | Pod 崩溃循环 | 5m | critical |
| `PodOOMKilled` | Pod OOM | 1m | critical |

---

## 七、常用命令

```bash
# 查看所有 PrometheusRule
kubectl get prometheusrule -n monitoring

# 查看当前触发的告警
curl -s http://182.42.82.135:30903/api/v2/alerts | python3 -m json.tool

# 查看静默规则
curl -s http://182.42.82.135:30903/api/v2/silences | python3 -m json.tool

# 查看 AlertManager 配置
kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
```

---

## 八、常见问题排查

### Q1: 告警规则不生效

```bash
# 1. 检查 PrometheusRule 标签
kubectl get prometheusrule my-rules -n monitoring -o yaml | grep -A5 labels
# 必须有 release: prometheus

# 2. 检查 Prometheus 是否加载了规则
curl http://182.42.82.135:30909/api/v1/rules | grep "my-rules"

# 3. 检查 PromQL 表达式
curl "http://182.42.82.135:30909/api/v1/query?query=your_expr"
```

### Q2: 告警触发但没收到通知

```bash
# 1. 检查 AlertManager 是否收到告警
curl http://182.42.82.135:30903/api/v2/alerts

# 2. 检查是否被静默
curl http://182.42.82.135:30903/api/v2/silences

# 3. 检查 Webhook URL 是否可达
curl -X POST http://your-webhook-url -d '{"test": "message"}'
```

### Q3: 告警风暴

**解决方案**：
1. 增加 `for` 时间（避免瞬时抖动）
2. 调整 `group_wait`（等待更多告警聚合）
3. 增加 `repeat_interval`（减少重复发送）
4. 添加抑制规则（抑制衍生告警）
5. 创建静默规则（临时屏蔽已知问题）

---

## 九、金句收藏

```
"Prometheus 是发现问题的眼睛，AlertManager 是通知问题的嘴巴"

"好的告警系统：该响的时候响，不该响的时候静"

"告警不是越多越好，而是越准越好"
```

---

## 十、延伸资源

- [AlertManager 官方文档](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [AlertManager 配置详解](https://prometheus.io/docs/alerting/latest/configuration/)
- 操作指南：[创建告警规则](../guides/create-alert-rule.md)
- 操作指南：[告警静默操作](../guides/silence-alerts.md)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- AlertManager 版本：v0.27.0
- 适用环境：kube-prometheus-stack v72.6.2
