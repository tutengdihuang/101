# Grafana 模板变量（Template Variables）工作原理

## 概述

Grafana 模板变量允许你创建动态的、可交互的 Dashboard，用户可以通过下拉菜单选择不同的值，Dashboard 会根据选择的值动态更新所有相关的查询和面板。

## 核心机制

### 1. 变量定义

在 Dashboard JSON 的 `templating.list` 部分定义变量：

```json
{
  "templating": {
    "list": [
      {
        "name": "node",
        "type": "query",
        "datasource": "Prometheus",
        "query": {
          "query": "label_values(up, instance)",
          "refId": "StandardVariableQuery"
        },
        "definition": "label_values(up, instance)",
        "refresh": 1,
        "includeAll": true,
        "multi": true,
        "allValue": ".*",
        "label": "Node"
      }
    ]
  }
}
```

### 2. 变量类型

Grafana 支持多种变量类型：

#### Query 类型（最常用）
从数据源动态获取值：

```json
{
  "type": "query",
  "datasource": "Prometheus",
  "query": "label_values(up, instance)"
}
```

**PromQL 查询语法：**
- `label_values(metric, label)` - 获取指定指标的所有标签值
- `label_values(metric)` - 获取所有标签名
- `query_result(query)` - 执行查询并返回结果

**示例：**
```promql
# 获取所有节点实例
label_values(up, instance)

# 获取所有命名空间
label_values(kube_pod_info, namespace)

# 获取所有 Pod 名称
label_values(kube_pod_info{namespace="default"}, pod)

# 获取所有 job 名称
label_values(up, job)
```

#### Interval 类型
时间间隔变量：

```json
{
  "type": "interval",
  "name": "interval",
  "auto": false,
  "auto_count": 30,
  "auto_min": "10s",
  "query": "1m,5m,10m,30m,1h,6h,12h,1d",
  "current": {
    "selected": false,
    "text": "5m",
    "value": "5m"
  }
}
```

#### Constant 类型
常量变量：

```json
{
  "type": "constant",
  "name": "threshold",
  "query": "80",
  "current": {
    "selected": false,
    "text": "80",
    "value": "80"
  }
}
```

#### Custom 类型
自定义选项：

```json
{
  "type": "custom",
  "name": "environment",
  "query": "dev,staging,prod",
  "current": {
    "selected": false,
    "text": "prod",
    "value": "prod"
  }
}
```

### 3. 变量使用

在查询中使用变量，使用 `$variable_name` 或 `${variable_name}` 语法：

#### 在 PromQL 查询中使用

```promql
# 精确匹配
up{instance="$node"}

# 正则匹配
up{instance=~"$node"}

# 多选时使用
up{instance=~"$node"}

# 在标题中使用
CPU Usage for $node
```

#### 在标题和描述中使用

```json
{
  "title": "CPU Usage for $node",
  "description": "Showing metrics for $node"
}
```

#### 在其他字段中使用

```json
{
  "legendFormat": "{{instance}} ($node)",
  "datasource": "$datasource"
}
```

### 4. 变量选项配置

#### includeAll - 包含"全部"选项

```json
{
  "includeAll": true,
  "allValue": ".*",
  "multi": true
}
```

- `includeAll: true` - 添加"All"选项到下拉菜单
- `allValue: ".*"` - 选择"All"时使用的值（正则表达式匹配所有）
- `multi: true` - 允许多选

#### refresh - 刷新策略

```json
{
  "refresh": 1
}
```

刷新选项：
- `0` - Never（从不刷新）
- `1` - On Dashboard Load（加载 Dashboard 时刷新）
- `2` - On Time Range Change（时间范围改变时刷新）

#### multi - 多选支持

```json
{
  "multi": true
}
```

允许用户选择多个值。

### 5. 变量链（Chained Variables）

变量可以依赖其他变量，创建级联选择：

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(kube_pod_info, namespace)"
      },
      {
        "name": "pod",
        "type": "query",
        "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)"
      }
    ]
  }
}
```

当用户选择命名空间后，Pod 变量会自动更新为该命名空间下的 Pod。

### 6. 变量高级功能

#### 正则表达式过滤

```json
{
  "query": "label_values(up, instance)",
  "regex": "/.*master.*/"
}
```

只匹配包含"master"的实例。

#### 排序选项

```json
{
  "sort": 1
}
```

排序选项：
- `1` - Alphabetical (asc)（字母升序）
- `2` - Alphabetical (desc)（字母降序）
- `3` - Numerical (asc)（数字升序）
- `4` - Numerical (desc)（数字降序）
- `5` - Alphabetical (case-insensitive, asc)（不区分大小写升序）
- `6` - Alphabetical (case-insensitive, desc)（不区分大小写降序）

#### 自定义显示文本

```json
{
  "options": [
    {
      "selected": true,
      "text": "Production",
      "value": "prod"
    },
    {
      "selected": false,
      "text": "Staging",
      "value": "staging"
    }
  ]
}
```

### 7. 实际应用示例

#### 示例 1：按命名空间和 Pod 过滤

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(kube_pod_info, namespace)",
        "includeAll": true,
        "allValue": ".*",
        "multi": false
      },
      {
        "name": "pod",
        "type": "query",
        "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)",
        "includeAll": true,
        "allValue": ".*",
        "multi": true
      }
    ]
  }
}
```

查询中使用：
```promql
rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$pod"}[5m])
```

#### 示例 2：按节点和容器过滤

```json
{
  "templating": {
    "list": [
      {
        "name": "node",
        "type": "query",
        "query": "label_values(up, instance)",
        "includeAll": true,
        "multi": true
      },
      {
        "name": "container",
        "type": "query",
        "query": "label_values(container_cpu_usage_seconds_total{instance=~\"$node\"}, container)"
      }
    ]
  }
}
```

查询中使用：
```promql
rate(container_cpu_usage_seconds_total{instance=~"$node", container="$container"}[5m])
```

#### 示例 3：动态时间范围

```json
{
  "templating": {
    "list": [
      {
        "name": "interval",
        "type": "interval",
        "query": "1m,5m,10m,30m,1h",
        "auto": false,
        "current": {
          "text": "5m",
          "value": "5m"
        }
      }
    ]
  }
}
```

查询中使用：
```promql
rate(container_cpu_usage_seconds_total[$interval])
```

### 8. 变量语法速查

| 语法 | 说明 | 示例 |
|------|------|------|
| `$var` | 简单变量替换 | `$node` |
| `${var}` | 带花括号的变量 | `${node}` |
| `${var:raw}` | 原始值（不转义） | `${node:raw}` |
| `${var:csv}` | CSV 格式 | `${node:csv}` |
| `${var:doublequote}` | 双引号包围 | `${node:doublequote}` |
| `${var:singlequote}` | 单引号包围 | `${node:singlequote}` |

### 9. 最佳实践

1. **使用有意义的变量名**
   ```json
   {"name": "namespace"}  // 好
   {"name": "ns"}          // 不好
   ```

2. **提供清晰的标签**
   ```json
   {"label": "Select Namespace"}  // 好
   {"label": "NS"}                 // 不好
   ```

3. **合理使用 includeAll 和 multi**
   - 对于分类变量（如命名空间），使用 `includeAll: true, multi: false`
   - 对于实例变量（如 Pod），使用 `includeAll: true, multi: true`

4. **设置适当的刷新策略**
   - 静态数据使用 `refresh: 0`
   - 动态数据使用 `refresh: 1`

5. **使用变量链创建级联选择**
   - 先选择大类（如命名空间）
   - 再选择小类（如 Pod）

6. **在查询中使用正则匹配**
   ```promql
   {instance=~"$node"}  // 使用 =~ 支持多选
   {instance="$node"}   // 使用 = 仅支持单选
   ```

## 总结

Grafana 模板变量通过以下机制实现数据动态写入：

1. **定义变量**：在 `templating.list` 中定义变量及其数据源
2. **获取数据**：从数据源（如 Prometheus）动态获取选项值
3. **用户选择**：用户通过下拉菜单选择值
4. **变量替换**：Grafana 将变量值替换到查询、标题等位置
5. **动态更新**：Dashboard 根据选择的值动态更新所有面板

这种机制使得单个 Dashboard 可以灵活地展示不同维度的数据，大大提高了 Dashboard 的复用性和灵活性。
