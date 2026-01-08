# Grafana 基础

> 一句话概括：Grafana 是监控数据的"画家"，把枯燥的数字变成直观的图表。

## 核心概念

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| **Dashboard** | 多个图表的集合 | 汽车仪表盘 |
| **Panel** | 单个图表 | 速度表、油量表 |
| **Data Source** | 数据来源 | 传感器 |
| **Variable** | 动态参数 | 切换查看不同车辆 |

---

## 一、Dashboard 概述

### 1.1 Dashboard 结构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Dashboard                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Dashboard Header                      │   │
│  │  标题 | 变量选择器 | 时间范围 | 刷新按钮                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Panel 1   │  │   Panel 2   │  │   Panel 3   │            │
│  │   (Stat)    │  │   (Stat)    │  │   (Gauge)   │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                      Panel 4 (Timeseries)                  │ │
│  │   ╭────────────────────────────────────────────────────╮  │ │
│  │   │                                                    │  │ │
│  │   │     ╱╲    ╱╲                                       │  │ │
│  │   │    ╱  ╲  ╱  ╲                                      │  │ │
│  │   │   ╱    ╲╱    ╲                                     │  │ │
│  │   ╰────────────────────────────────────────────────────╯  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐ │
│  │      Panel 5 (Table)    │  │      Panel 6 (Piechart)     │ │
│  └─────────────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Dashboard JSON 结构

```json
{
  "title": "My Dashboard",
  "uid": "my-dashboard",
  "tags": ["devops", "kubernetes"],
  "timezone": "Asia/Shanghai",
  "refresh": "30s",
  "panels": [
    {
      "id": 1,
      "title": "Panel Title",
      "type": "stat",
      "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 },
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "count(kube_pod_info)",
          "refId": "A"
        }
      ]
    }
  ]
}
```

---

## 二、Panel 类型

### 2.1 常用 Panel 类型

| 类型 | 图标 | 适用场景 | 示例 |
|------|------|---------|------|
| **Stat** | 📊 | 显示单个数值 | Pod 数量、CPU 使用率 |
| **Gauge** | 🎯 | 显示百分比 | 磁盘使用率、内存使用率 |
| **Timeseries** | 📈 | 显示趋势 | CPU 历史曲线 |
| **Table** | 📋 | 显示列表 | Pod 列表、告警列表 |
| **Piechart** | 🥧 | 显示占比 | 资源分布 |
| **Heatmap** | 🔥 | 显示密度 | 请求延迟分布 |
| **Bar Chart** | 📊 | 显示对比 | 各节点资源对比 |

### 2.2 Stat Panel

**用途**：显示单个数值，如 Pod 数量、CPU 使用率

```json
{
  "type": "stat",
  "title": "Running Pods",
  "targets": [
    {
      "expr": "count(kube_pod_status_phase{phase=\"Running\"})",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "short",
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "red", "value": 100 }
        ]
      }
    }
  },
  "options": {
    "colorMode": "value",
    "graphMode": "area"
  }
}
```

### 2.3 Gauge Panel

**用途**：显示百分比，如磁盘使用率

```json
{
  "type": "gauge",
  "title": "Disk Usage",
  "targets": [
    {
      "expr": "(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100,
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 70 },
          { "color": "red", "value": 90 }
        ]
      }
    }
  }
}
```

### 2.4 Timeseries Panel

**用途**：显示时间序列趋势

```json
{
  "type": "timeseries",
  "title": "CPU Usage Over Time",
  "targets": [
    {
      "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
      "legendFormat": "{{instance}}",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "custom": {
        "drawStyle": "line",
        "lineWidth": 1,
        "fillOpacity": 10
      }
    }
  },
  "options": {
    "legend": {
      "displayMode": "list",
      "placement": "bottom"
    }
  }
}
```

### 2.5 Table Panel

**用途**：显示列表数据

```json
{
  "type": "table",
  "title": "Pod List",
  "targets": [
    {
      "expr": "kube_pod_info",
      "format": "table",
      "instant": true,
      "refId": "A"
    }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": {
          "Time": true,
          "Value": true
        },
        "renameByName": {
          "namespace": "Namespace",
          "pod": "Pod Name"
        }
      }
    }
  ]
}
```

---

## 三、数据源配置

### 3.1 添加 Prometheus 数据源

**通过 UI 添加**：
1. 访问 Grafana → Configuration → Data Sources
2. 点击 "Add data source"
3. 选择 "Prometheus"
4. 配置 URL：`http://prometheus-operated.monitoring.svc:9090`
5. 点击 "Save & Test"

**通过 API 添加**：
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus-operated.monitoring.svc:9090",
    "access": "proxy",
    "isDefault": true
  }' \
  http://admin:admin123@182.42.82.135:30300/api/datasources
```

### 3.2 数据源配置说明

| 字段 | 说明 | 示例 |
|------|------|------|
| `name` | 数据源名称 | Prometheus |
| `type` | 数据源类型 | prometheus |
| `url` | 数据源地址 | http://prometheus:9090 |
| `access` | 访问方式 | proxy（通过 Grafana 代理） |
| `isDefault` | 是否默认 | true |

---

## 四、变量 (Variables)

### 4.1 变量类型

| 类型 | 说明 | 示例 |
|------|------|------|
| **Query** | 从数据源查询 | 查询所有 namespace |
| **Custom** | 自定义列表 | dev, test, prod |
| **Constant** | 常量 | 固定值 |
| **Interval** | 时间间隔 | 1m, 5m, 15m |

### 4.2 Query 变量示例

**查询所有 Namespace**：
```
label_values(kube_pod_info, namespace)
```

**查询指定 Namespace 的 Pod**：
```
label_values(kube_pod_info{namespace="$namespace"}, pod)
```

**查询所有节点**：
```
label_values(node_uname_info, nodename)
```

### 4.3 在 Panel 中使用变量

```promql
# 使用 $namespace 变量
count(kube_pod_info{namespace="$namespace"})

# 使用 $pod 变量
container_memory_working_set_bytes{pod="$pod"}

# 使用正则匹配多选
kube_pod_info{namespace=~"$namespace"}
```

### 4.4 变量配置示例

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(kube_pod_info, namespace)",
        "refresh": 1,
        "multi": true,
        "includeAll": true
      },
      {
        "name": "pod",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(kube_pod_info{namespace=~\"$namespace\"}, pod)",
        "refresh": 1,
        "multi": false
      }
    ]
  }
}
```

---

## 五、阈值和颜色

### 5.1 阈值配置

```json
{
  "thresholds": {
    "mode": "absolute",
    "steps": [
      { "color": "green", "value": null },    // 默认绿色
      { "color": "yellow", "value": 70 },     // >= 70 黄色
      { "color": "red", "value": 90 }         // >= 90 红色
    ]
  }
}
```

### 5.2 颜色模式

| 模式 | 说明 |
|------|------|
| `value` | 根据值显示颜色 |
| `background` | 背景色变化 |
| `fixed` | 固定颜色 |
| `palette-classic` | 经典调色板 |

### 5.3 单位配置

常用单位：

| 单位 | 说明 | 示例 |
|------|------|------|
| `short` | 短格式 | 1234 → 1.23K |
| `percent` | 百分比 | 0.85 → 85% |
| `bytes` | 字节 | 1073741824 → 1 GiB |
| `decbytes` | 十进制字节 | 1000000000 → 1 GB |
| `s` | 秒 | 3600 → 1h |
| `ms` | 毫秒 | 1500 → 1.5s |

---

## 六、Dashboard 管理

### 6.1 导出 Dashboard

**通过 UI**：
1. 打开 Dashboard
2. 点击 Share → Export
3. 选择 "Save to file"

**通过 API**：
```bash
# 获取 Dashboard JSON
curl http://admin:admin123@182.42.82.135:30300/api/dashboards/uid/devops-overview
```

### 6.2 导入 Dashboard

**通过 UI**：
1. 点击 "+" → "Import"
2. 上传 JSON 文件或粘贴 JSON
3. 选择数据源
4. 点击 "Import"

**通过 API**：
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": { ... },
    "overwrite": true
  }' \
  http://admin:admin123@182.42.82.135:30300/api/dashboards/db
```

### 6.3 Dashboard 版本控制

Grafana 自动保存 Dashboard 历史版本：
1. 打开 Dashboard
2. 点击 Settings → Versions
3. 可以查看、比较、恢复历史版本

---

## 七、常用 Dashboard 推荐

### 7.1 官方 Dashboard

| Dashboard ID | 名称 | 用途 |
|-------------|------|------|
| 1860 | Node Exporter Full | 节点详细监控 |
| 315 | Kubernetes Cluster | K8s 集群概览 |
| 6417 | Kubernetes Pods | Pod 监控 |
| 13770 | Kubernetes Overview | K8s 概览 |

### 7.2 导入官方 Dashboard

1. 访问 https://grafana.com/grafana/dashboards/
2. 搜索需要的 Dashboard
3. 复制 Dashboard ID
4. 在 Grafana 中：Import → 输入 ID → Load

---

## 八、最佳实践

### 8.1 Dashboard 设计原则

1. **一目了然**：重要指标放在最上面
2. **层次分明**：概览 → 详情 → 明细
3. **颜色一致**：绿色=正常，黄色=警告，红色=严重
4. **适当留白**：不要塞满整个屏幕

### 8.2 Panel 设计原则

1. **标题清晰**：一眼就知道显示什么
2. **单位正确**：百分比、字节、秒等
3. **阈值合理**：根据实际情况设置
4. **图例简洁**：使用 `{{instance}}` 等模板

### 8.3 查询优化

```promql
# ❌ 不好：查询所有数据再过滤
sum(container_memory_working_set_bytes)

# ✅ 好：在查询时就过滤
sum(container_memory_working_set_bytes{namespace="default"})

# ❌ 不好：使用 irate 做告警
irate(http_requests_total[5m]) > 100

# ✅ 好：使用 rate 做告警（更稳定）
rate(http_requests_total[5m]) > 100
```

---

## 九、常见问题

### Q1: Panel 显示 "No data"

**可能原因**：
1. PromQL 查询语法错误
2. 时间范围内没有数据
3. 数据源配置错误

**排查步骤**：
1. 在 Prometheus UI 中测试查询
2. 检查时间范围是否正确
3. 检查数据源连接

### Q2: 变量不生效

**可能原因**：
1. 变量名拼写错误
2. 没有使用 `$` 前缀
3. 多选变量没有使用 `=~`

**正确用法**：
```promql
# 单选变量
kube_pod_info{namespace="$namespace"}

# 多选变量
kube_pod_info{namespace=~"$namespace"}
```

### Q3: Dashboard 加载慢

**优化方法**：
1. 减少 Panel 数量
2. 优化 PromQL 查询
3. 增加刷新间隔
4. 使用 `instant` 查询代替范围查询

---

## 延伸阅读

- [创建 Dashboard 指南](../guides/create-dashboard.md) - 动手实践
- [09-PromQL 查询手册](09-promql-cookbook.md) - 更多查询示例
- [Grafana 官方文档](https://grafana.com/docs/)
