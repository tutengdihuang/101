# 创建 Grafana Dashboard

> 📊 如何创建自定义可视化面板

## 一、访问 Grafana

| 信息 | 值 |
|------|-----|
| 地址 | http://182.42.82.135:30300 |
| 用户名 | admin |
| 密码 | admin123 |

---

## 二、快速创建 Dashboard

### 2.1 创建新 Dashboard

1. 登录 Grafana
2. 点击左侧菜单 `+` → `New dashboard`
3. 点击 `Add visualization`
4. 选择数据源 `Prometheus`

### 2.2 添加 Panel

1. 在 Query 区域输入 PromQL
2. 选择可视化类型（Graph、Stat、Gauge 等）
3. 配置 Panel 标题和描述
4. 点击 `Apply` 保存

---

## 三、常用 Panel 示例

### 3.1 CPU 使用率（Gauge）

**PromQL**：
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

### 3.2 内存使用率（Gauge）

**PromQL**：
```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

### 3.3 磁盘使用率（Gauge）

**PromQL**：
```promql
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

### 3.4 网络流量（Time Series）

**PromQL（接收）**：
```promql
rate(node_network_receive_bytes_total{device="eth0"}[5m]) / 1024 / 1024
```

**PromQL（发送）**：
```promql
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) / 1024 / 1024
```

**配置**：
- Visualization: Time series
- Unit: MB/s
- Legend: {{instance}} - {{device}}

### 3.5 Pod 状态（Stat）

**PromQL**：
```promql
sum by(phase) (kube_pod_status_phase)
```

**配置**：
- Visualization: Stat
- Calculation: Last
- Color mode: Value

### 3.6 Top 10 内存使用 Pod（Table）

**PromQL**：
```promql
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""})) / 1024 / 1024
```

**配置**：
- Visualization: Table
- Unit: MB
- Sort: Descending

---

## 四、使用变量

### 4.1 创建变量

1. Dashboard Settings → Variables → Add variable
2. 配置变量

**命名空间变量**：
```
Name: namespace
Type: Query
Data source: Prometheus
Query: label_values(kube_pod_info, namespace)
Multi-value: Yes
Include All option: Yes
```

**节点变量**：
```
Name: node
Type: Query
Data source: Prometheus
Query: label_values(node_uname_info, nodename)
Multi-value: Yes
Include All option: Yes
```

### 4.2 在 Panel 中使用变量

```promql
# 使用 namespace 变量
container_memory_working_set_bytes{namespace=~"$namespace"}

# 使用 node 变量
node_cpu_seconds_total{instance=~"$node.*"}
```

---

## 五、导入现有 Dashboard

### 5.1 从 Grafana.com 导入

1. 访问 https://grafana.com/grafana/dashboards/
2. 找到需要的 Dashboard，复制 ID
3. Grafana → Dashboards → Import
4. 输入 Dashboard ID
5. 选择数据源
6. 点击 Import

### 5.2 推荐 Dashboard

| Dashboard | ID | 说明 |
|-----------|-----|------|
| Node Exporter Full | 1860 | 节点监控 |
| Kubernetes Cluster | 315 | K8s 集群概览 |
| Kubernetes Pods | 6336 | Pod 监控 |
| Prometheus Stats | 2 | Prometheus 自身监控 |

### 5.3 从 JSON 导入

1. Grafana → Dashboards → Import
2. 粘贴 JSON 或上传 JSON 文件
3. 选择数据源
4. 点击 Import

---

## 六、Dashboard JSON 示例

### 6.1 简单节点监控 Dashboard

```json
{
  "title": "Node Overview",
  "panels": [
    {
      "title": "CPU Usage",
      "type": "gauge",
      "targets": [
        {
          "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 85}
            ]
          }
        }
      },
      "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
    },
    {
      "title": "Memory Usage",
      "type": "gauge",
      "targets": [
        {
          "expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 85}
            ]
          }
        }
      },
      "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
    }
  ],
  "schemaVersion": 38,
  "version": 1
}
```

---

## 七、最佳实践

### 7.1 Dashboard 组织

```
📁 Dashboards
├── 📁 Infrastructure
│   ├── Node Overview
│   ├── Kubernetes Cluster
│   └── Network
├── 📁 Applications
│   ├── My App
│   └── API Gateway
└── 📁 CI/CD
    ├── Tekton Pipelines
    └── ArgoCD
```

### 7.2 Panel 设计原则

1. **一个 Panel 一个指标**：避免信息过载
2. **使用合适的可视化类型**：
   - 当前值 → Stat/Gauge
   - 趋势 → Time Series
   - 列表 → Table
3. **设置合理的阈值**：使用颜色区分状态
4. **添加描述**：说明指标含义

### 7.3 性能优化

1. **限制时间范围**：避免查询过长时间的数据
2. **使用 `$__interval`**：自动调整聚合间隔
3. **减少 Panel 数量**：每个 Dashboard 不超过 20 个 Panel

---

## 八、导出 Dashboard

### 8.1 导出为 JSON

1. Dashboard Settings → JSON Model
2. 复制 JSON 内容
3. 保存为 `.json` 文件

### 8.2 通过 API 导出

```bash
# 获取 Dashboard JSON
curl -H "Authorization: Bearer <api-key>" \
  http://182.42.82.135:30300/api/dashboards/uid/<dashboard-uid>
```

---

## 九、常见问题

### Q1: Panel 显示 No Data

可能原因：
1. PromQL 表达式错误
2. 时间范围内没有数据
3. 数据源配置错误

解决方法：
1. 在 Prometheus UI 测试表达式
2. 调整时间范围
3. 检查数据源配置

### Q2: 变量不生效

检查：
1. 变量名是否正确（区分大小写）
2. PromQL 中是否使用了 `=~` 而不是 `=`
3. 变量是否有值

### Q3: Dashboard 加载慢

优化：
1. 减少 Panel 数量
2. 缩短时间范围
3. 使用 `$__interval` 自动聚合

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- Grafana 版本：10.4.2
