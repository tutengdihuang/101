# 创建 Grafana Dashboard：打造你的监控大屏

> 🎯 **一句话精华**：Dashboard = 数据的可视化窗口——把枯燥的数字变成一目了然的图表！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Prometheus 有数据，但看起来像天书
Grafana Dashboard 把数据变成图表
让你一眼就能看出系统健康状况
```

**适合谁学**：需要创建自定义监控面板的运维/开发人员
**不适合谁**：只使用现成 Dashboard 的用户

---

## 二、访问 Grafana

| 信息 | 值 |
|------|-----|
| 地址 | `http://<grafana-ip>:<port>` |
| 默认用户名 | admin |
| 默认密码 | 安装时设置的密码 |

---

## 三、快速创建 Dashboard

### 3.1 创建新 Dashboard

1. 登录 Grafana
2. 点击左侧菜单 `+` → `New dashboard`
3. 点击 `Add visualization`
4. 选择数据源 `Prometheus`

### 3.2 添加 Panel

1. 在 Query 区域输入 PromQL
2. 选择可视化类型（Graph、Stat、Gauge 等）
3. 配置 Panel 标题和描述
4. 点击 `Apply` 保存

---

## 四、常用 Panel 示例

### 4.1 CPU 使用率（Gauge 仪表盘）

**PromQL**：
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

**效果**：像汽车仪表盘一样显示 CPU 使用率

### 4.2 内存使用率（Gauge 仪表盘）

**PromQL**：
```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

### 4.3 磁盘使用率（Gauge 仪表盘）

**PromQL**：
```promql
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
```

**配置**：
- Visualization: Gauge
- Unit: Percent (0-100)
- Thresholds: 0=green, 70=yellow, 85=red

### 4.4 网络流量（Time Series 时序图）

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

### 4.5 Pod 状态（Stat 统计）

**PromQL**：
```promql
sum by(phase) (kube_pod_status_phase)
```

**配置**：
- Visualization: Stat
- Calculation: Last
- Color mode: Value

### 4.6 Top 10 内存使用 Pod（Table 表格）

**PromQL**：
```promql
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""})) / 1024 / 1024
```

**配置**：
- Visualization: Table
- Unit: MB
- Sort: Descending

---

## 五、使用变量（让 Dashboard 更灵活）

### 5.1 创建变量

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

### 5.2 在 Panel 中使用变量

```promql
# 使用 namespace 变量
container_memory_working_set_bytes{namespace=~"$namespace"}

# 使用 node 变量
node_cpu_seconds_total{instance=~"$node.*"}
```

**生活化比喻**：
```
变量就像筛选器：
- 不用变量 = 看所有数据
- 用变量 = 只看你关心的数据
就像电商网站的"筛选条件"
```

---

## 六、导入现有 Dashboard

### 6.1 从 Grafana.com 导入

1. 访问 https://grafana.com/grafana/dashboards/
2. 找到需要的 Dashboard，复制 ID
3. Grafana → Dashboards → Import
4. 输入 Dashboard ID
5. 选择数据源
6. 点击 Import

### 6.2 推荐 Dashboard

| Dashboard | ID | 说明 |
|-----------|-----|------|
| Node Exporter Full | 1860 | 节点监控（超详细） |
| Kubernetes Cluster | 315 | K8s 集群概览 |
| Kubernetes Pods | 6336 | Pod 监控 |
| Prometheus Stats | 2 | Prometheus 自身监控 |

### 6.3 从 JSON 导入

1. Grafana → Dashboards → Import
2. 粘贴 JSON 或上传 JSON 文件
3. 选择数据源
4. 点击 Import

---

## 七、Dashboard JSON 示例

### 7.1 简单节点监控 Dashboard

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

## 八、最佳实践

### 8.1 Dashboard 组织

```
📁 Dashboards
├── 📁 Infrastructure（基础设施）
│   ├── Node Overview
│   ├── Kubernetes Cluster
│   └── Network
├── 📁 Applications（应用）
│   ├── My App
│   └── API Gateway
└── 📁 CI/CD
    ├── Tekton Pipelines
    └── ArgoCD
```

### 8.2 Panel 设计原则

1. **一个 Panel 一个指标**：避免信息过载
2. **使用合适的可视化类型**：
   - 当前值 → Stat/Gauge
   - 趋势 → Time Series
   - 列表 → Table
3. **设置合理的阈值**：使用颜色区分状态
4. **添加描述**：说明指标含义

### 8.3 性能优化

1. **限制时间范围**：避免查询过长时间的数据
2. **使用 `$__interval`**：自动调整聚合间隔
3. **减少 Panel 数量**：每个 Dashboard 不超过 20 个 Panel

---

## 九、导出 Dashboard

### 9.1 导出为 JSON

1. Dashboard Settings → JSON Model
2. 复制 JSON 内容
3. 保存为 `.json` 文件

### 9.2 通过 API 导出

```bash
# 获取 Dashboard JSON
curl -H "Authorization: Bearer <api-key>" \
  http://<grafana-ip>:<port>/api/dashboards/uid/<dashboard-uid>
```

---

## 十、常见问题

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

## 十一、金句收藏

```
"好的 Dashboard = 一眼就能看出问题"

"Panel 不是越多越好，而是越清晰越好"

"颜色是最好的告警：绿色安心，黄色注意，红色行动"

"变量让 Dashboard 从'死板'变'灵活'"
```

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：Grafana 10.x

---

> 📝 **系列导航**：
> - 上一篇：[创建告警规则](create-alert-rule.md)
> - 下一篇：[安装部署指南](installation.md)
