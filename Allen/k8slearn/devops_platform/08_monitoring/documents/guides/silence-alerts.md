# 告警静默操作

> 🔇 如何在维护期间临时屏蔽告警

## 一、什么是静默

静默（Silence）是 AlertManager 的功能，用于临时屏蔽符合条件的告警，常用于：

- 计划内维护
- 已知问题正在处理中
- 测试环境不需要告警

---

## 二、通过 UI 创建静默

### 2.1 访问 AlertManager

访问地址：http://182.42.82.135:30903

### 2.2 创建静默

1. 点击顶部菜单 `Silences`
2. 点击 `New Silence` 按钮
3. 填写静默配置：

**匹配条件**（Matchers）：
```
alertname = NodeHighCPUUsage
instance = 192.168.1.10:9100
```

**时间范围**：
- Start: 2026-01-05 10:00
- End: 2026-01-05 12:00

**备注信息**：
- Creator: zhangsan
- Comment: 节点维护，升级内核

4. 点击 `Create` 创建

### 2.3 从告警创建静默

1. 在 `Alerts` 页面找到要静默的告警
2. 点击告警右侧的 `Silence` 按钮
3. 系统会自动填充匹配条件
4. 设置时间范围和备注
5. 点击 `Create`

---

## 三、通过 API 创建静默

### 3.1 创建静默

```bash
curl -X POST http://182.42.82.135:30903/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "NodeHighCPUUsage",
        "isRegex": false
      },
      {
        "name": "instance",
        "value": "192.168.1.10:9100",
        "isRegex": false
      }
    ],
    "startsAt": "2026-01-05T10:00:00Z",
    "endsAt": "2026-01-05T12:00:00Z",
    "createdBy": "admin",
    "comment": "节点维护，升级内核"
  }'
```

### 3.2 使用正则匹配

```bash
curl -X POST http://182.42.82.135:30903/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "Node.*",
        "isRegex": true
      }
    ],
    "startsAt": "2026-01-05T10:00:00Z",
    "endsAt": "2026-01-05T12:00:00Z",
    "createdBy": "admin",
    "comment": "静默所有节点相关告警"
  }'
```

### 3.3 查看所有静默

```bash
curl -s http://182.42.82.135:30903/api/v2/silences | python3 -m json.tool
```

### 3.4 删除静默

```bash
# 获取静默 ID
curl -s http://182.42.82.135:30903/api/v2/silences | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data:
    print(f\"ID: {s['id']}, Comment: {s['comment']}, Status: {s['status']['state']}\")"

# 删除静默
curl -X DELETE http://182.42.82.135:30903/api/v2/silence/<silence-id>
```

---

## 四、常用静默场景

### 4.1 静默单个告警

```json
{
  "matchers": [
    {"name": "alertname", "value": "NodeHighCPUUsage", "isRegex": false}
  ],
  "startsAt": "2026-01-05T10:00:00Z",
  "endsAt": "2026-01-05T12:00:00Z",
  "createdBy": "admin",
  "comment": "CPU 升级测试"
}
```

### 4.2 静默某个节点的所有告警

```json
{
  "matchers": [
    {"name": "instance", "value": "192.168.1.10:9100", "isRegex": false}
  ],
  "startsAt": "2026-01-05T10:00:00Z",
  "endsAt": "2026-01-05T12:00:00Z",
  "createdBy": "admin",
  "comment": "节点维护"
}
```

### 4.3 静默某个命名空间的所有告警

```json
{
  "matchers": [
    {"name": "namespace", "value": "test", "isRegex": false}
  ],
  "startsAt": "2026-01-05T10:00:00Z",
  "endsAt": "2026-01-05T12:00:00Z",
  "createdBy": "admin",
  "comment": "测试环境维护"
}
```

### 4.4 静默所有 warning 级别告警

```json
{
  "matchers": [
    {"name": "severity", "value": "warning", "isRegex": false}
  ],
  "startsAt": "2026-01-05T10:00:00Z",
  "endsAt": "2026-01-05T12:00:00Z",
  "createdBy": "admin",
  "comment": "只关注 critical 告警"
}
```

### 4.5 使用正则静默多个告警

```json
{
  "matchers": [
    {"name": "alertname", "value": "^(Tekton|ArgoCD).*", "isRegex": true}
  ],
  "startsAt": "2026-01-05T10:00:00Z",
  "endsAt": "2026-01-05T12:00:00Z",
  "createdBy": "admin",
  "comment": "CI/CD 系统维护"
}
```

---

## 五、静默管理

### 5.1 查看活跃的静默

**通过 UI**：
1. 访问 http://182.42.82.135:30903/#/silences
2. 查看 `Active` 状态的静默

**通过 API**：
```bash
curl -s http://182.42.82.135:30903/api/v2/silences | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data:
    if s['status']['state'] == 'active':
        print(f\"ID: {s['id']}\"
              f\"\n  Comment: {s['comment']}\"
              f\"\n  Ends: {s['endsAt']}\"
              f\"\n  Matchers: {s['matchers']}\n\")"
```

### 5.2 延长静默时间

1. 在 UI 中找到要延长的静默
2. 点击 `Edit`
3. 修改结束时间
4. 点击 `Update`

或者通过 API 创建一个新的静默（相同匹配条件，新的时间范围）

### 5.3 提前结束静默

**通过 UI**：
1. 找到要结束的静默
2. 点击 `Expire` 按钮

**通过 API**：
```bash
curl -X DELETE http://182.42.82.135:30903/api/v2/silence/<silence-id>
```

---

## 六、最佳实践

### 6.1 静默规范

1. **必须填写 Comment**：说明静默原因
2. **设置合理的时间范围**：不要设置过长的静默时间
3. **使用精确匹配**：避免静默过多告警
4. **及时清理过期静默**：定期检查静默列表

### 6.2 静默审计

```bash
# 查看所有静默（包括过期的）
curl -s "http://182.42.82.135:30903/api/v2/silences?silenced=false" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data:
    print(f\"ID: {s['id']}\"
          f\"\n  Status: {s['status']['state']}\"
          f\"\n  Creator: {s['createdBy']}\"
          f\"\n  Comment: {s['comment']}\"
          f\"\n  Start: {s['startsAt']}\"
          f\"\n  End: {s['endsAt']}\n\")"
```

### 6.3 静默模板

创建常用静默的脚本：

```bash
#!/bin/bash
# silence-node.sh - 静默节点告警

NODE_IP=$1
DURATION=${2:-2h}  # 默认 2 小时
COMMENT=${3:-"节点维护"}

END_TIME=$(date -u -d "+${DURATION}" +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

curl -X POST http://182.42.82.135:30903/api/v2/silences \
  -H "Content-Type: application/json" \
  -d "{
    \"matchers\": [
      {\"name\": \"instance\", \"value\": \"${NODE_IP}:9100\", \"isRegex\": false}
    ],
    \"startsAt\": \"${START_TIME}\",
    \"endsAt\": \"${END_TIME}\",
    \"createdBy\": \"$(whoami)\",
    \"comment\": \"${COMMENT}\"
  }"

echo "静默已创建，将在 ${END_TIME} 结束"
```

使用方法：
```bash
./silence-node.sh 192.168.1.10 2h "升级内核"
```

---

## 七、常见问题

### Q1: 静默创建了但告警还在发送

可能原因：
1. 匹配条件不正确
2. 静默时间还没开始
3. 告警标签与匹配条件不一致

检查方法：
```bash
# 查看告警的标签
curl -s http://182.42.82.135:30903/api/v2/alerts | python3 -m json.tool

# 对比静默的匹配条件
curl -s http://182.42.82.135:30903/api/v2/silences | python3 -m json.tool
```

### Q2: 如何静默所有告警

```json
{
  "matchers": [
    {"name": "alertname", "value": ".*", "isRegex": true}
  ],
  "startsAt": "...",
  "endsAt": "...",
  "createdBy": "admin",
  "comment": "全局静默"
}
```

⚠️ **警告**：不建议这样做，可能会错过重要告警！

### Q3: 静默过期后告警会重新发送吗

是的，如果告警条件仍然满足，静默过期后告警会重新发送。

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- AlertManager 版本：v0.27.0
