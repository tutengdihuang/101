# Grafana 可视化入门：让数据会说话

> 🎯 **一句话精华**：Grafana 是监控数据的"画家"，把枯燥的数字变成直观的图表——让老板一眼就能看懂系统状态！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Prometheus 采集了一堆数字：12345.67, 98765.43, 55555.55...
你看得懂吗？老板看得懂吗？

Grafana 就是把这些数字变成漂亮图表的"魔法师"！
一条上升的红线，比一万个数字更有说服力！
```

**适合谁学**：需要做监控可视化的运维/开发人员
**不适合谁**：只想看现成 Dashboard 的用户（其实看看也挺好 😄）

---

## 二、开场故事：一图胜千言

> 某天，老板问小王："我们的服务器状态怎么样？"
> 
> 小王打开终端，噼里啪啦敲了一堆命令：
> ```
> CPU: 45.67%
> Memory: 78.23%
> Disk: 62.11%
> Network: 1234567 bytes/s
> ...
> ```
> 
> 老板看了 3 秒钟，眉头紧锁："所以...是好还是不好？"
> 
> 第二天，小王学会了 Grafana，给老板看了这个：
> 
> 📊 一个绿色的仪表盘，指针指向"健康"区域
> 📈 一条平稳的曲线，没有异常波动
> 🟢 所有指标都是绿色的"正常"状态
> 
> 老板满意地点点头："不错，继续保持！"

**这就是可视化的力量：让数据自己说话！**

---

## 三、核心概念速查表

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| **Dashboard** | 多个图表的集合 | 汽车仪表盘 | 一屏看全局 |
| **Panel** | 单个图表 | 速度表、油量表 | 一个图表一个故事 |
| **Data Source** | 数据来源 | 传感器 | 数据从哪来 |
| **Variable** | 动态参数 | 切换查看不同车辆 | 一个 Dashboard 看多个对象 |

---

## 四、Dashboard 结构解析

### 4.1 Dashboard 全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                        Dashboard                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Dashboard Header                      │   │
│  │  📌 标题 | 🔽 变量选择器 | 🕐 时间范围 | 🔄 刷新按钮      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Panel 1   │  │   Panel 2   │  │   Panel 3   │            │
│  │   (Stat)    │  │   (Stat)    │  │   (Gauge)   │            │
│  │   Pod 数量  │  │   节点数量  │  │   CPU 使用率 │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                   Panel 4 (Timeseries)                     │ │
│  │   📈 CPU 使用率趋势图                                      │ │
│  │   ╭────────────────────────────────────────────────────╮  │ │
│  │   │     ╱╲    ╱╲                                       │  │ │
│  │   │    ╱  ╲  ╱  ╲                                      │  │ │
│  │   │   ╱    ╲╱    ╲                                     │  │ │
│  │   ╰────────────────────────────────────────────────────╯  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐ │
│  │      Panel 5 (Table)    │  │      Panel 6 (Piechart)     │ │
│  │      Pod 列表           │  │      资源分布               │ │
│  └─────────────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Panel 类型选择指南

| 类型 | 图标 | 适用场景 | 示例 |
|------|------|---------|------|
| **Stat** | 📊 | 显示单个数值 | Pod 数量、CPU 使用率 |
| **Gauge** | 🎯 | 显示百分比 | 磁盘使用率、内存使用率 |
| **Timeseries** | 📈 | 显示趋势 | CPU 历史曲线 |
| **Table** | 📋 | 显示列表 | Pod 列表、告警列表 |
| **Piechart** | 🥧 | 显示占比 | 资源分布 |
| **Heatmap** | 🔥 | 显示密度 | 请求延迟分布 |
| **Bar Chart** | 📊 | 显示对比 | 各节点资源对比 |

**选择口诀**：
```
单个数字用 Stat，百分比用 Gauge
看趋势用 Timeseries，看列表用 Table
看占比用 Piechart，看分布用 Heatmap
```

---

## 五、常用 Panel 配置

### 5.1 Stat Panel（数值面板）

**用途**：显示单个数值，如 Pod 数量、CPU 使用率

**PromQL 示例**：
```promql
# 运行中的 Pod 数量
count(kube_pod_status_phase{phase="Running"})
```

**配置要点**：
- Unit（单位）：选择合适的单位（short、percent、bytes 等）
- Color mode：value（根据值变色）
- Thresholds：设置阈值颜色（绿→黄→红）

### 5.2 Gauge Panel（仪表盘）

**用途**：显示百分比，如磁盘使用率

**PromQL 示例**：
```promql
# 磁盘使用率
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
```

**配置要点**：
- Min/Max：设置 0-100
- Thresholds：0=绿色, 70=黄色, 90=红色

### 5.3 Timeseries Panel（时序图）

**用途**：显示时间序列趋势

**PromQL 示例**：
```promql
# CPU 使用率趋势
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**配置要点**：
- Legend：使用 `{{instance}}` 显示标签值
- Draw style：line（线图）、bars（柱状图）、points（点图）
- Fill opacity：填充透明度

### 5.4 Table Panel（表格）

**用途**：显示列表数据

**PromQL 示例**：
```promql
# Top 10 内存使用 Pod
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""})) / 1024 / 1024
```

**配置要点**：
- Format：选择 Table
- Instant：勾选（只显示最新值）
- Transformations：重命名列、隐藏列

---

## 六、变量的魔力

### 6.1 为什么需要变量？

**没有变量**：
```
你有 10 个命名空间，需要创建 10 个 Dashboard
每个 Dashboard 只是 namespace 不同
维护起来想哭 😭
```

**有了变量**：
```
创建 1 个 Dashboard，加一个 namespace 变量
下拉选择不同的 namespace，图表自动切换
维护起来很轻松 😄
```

### 6.2 创建变量

**步骤**：Dashboard Settings → Variables → Add variable

**常用变量配置**：

**命名空间变量**：
```
Name: namespace
Type: Query
Data source: Prometheus
Query: label_values(kube_pod_info, namespace)
Multi-value: Yes（允许多选）
Include All option: Yes（包含"全部"选项）
```

**节点变量**：
```
Name: node
Type: Query
Query: label_values(node_uname_info, nodename)
```

**Pod 变量（依赖 namespace）**：
```
Name: pod
Type: Query
Query: label_values(kube_pod_info{namespace=~"$namespace"}, pod)
```

### 6.3 在 Panel 中使用变量

```promql
# 使用 namespace 变量（单选）
container_memory_working_set_bytes{namespace="$namespace"}

# 使用 namespace 变量（多选，用正则）
container_memory_working_set_bytes{namespace=~"$namespace"}

# 使用多个变量
container_memory_working_set_bytes{namespace=~"$namespace", pod=~"$pod"}
```

---

## 七、阈值和颜色配置

### 7.1 阈值配置

阈值让图表"会说话"——绿色表示正常，黄色表示警告，红色表示危险。

**配置示例**：
```
Thresholds:
  - 0: green（正常）
  - 70: yellow（警告）
  - 90: red（危险）
```

### 7.2 常用单位

| 单位 | 说明 | 示例 |
|------|------|------|
| `short` | 短格式 | 1234 → 1.23K |
| `percent` | 百分比 | 0.85 → 85% |
| `bytes` | 字节（二进制） | 1073741824 → 1 GiB |
| `decbytes` | 字节（十进制） | 1000000000 → 1 GB |
| `s` | 秒 | 3600 → 1h |
| `ms` | 毫秒 | 1500 → 1.5s |

---

## 八、Dashboard 管理

### 8.1 导入官方 Dashboard

Grafana 社区有大量现成的 Dashboard，直接导入即可使用！

**步骤**：
1. 访问 https://grafana.com/grafana/dashboards/
2. 搜索需要的 Dashboard（如 "Node Exporter"）
3. 复制 Dashboard ID
4. Grafana → Dashboards → Import → 输入 ID → Load

**推荐 Dashboard**：

| Dashboard | ID | 说明 |
|-----------|-----|------|
| Node Exporter Full | 1860 | 节点监控（超详细！） |
| Kubernetes Cluster | 315 | K8s 集群概览 |
| Kubernetes Pods | 6336 | Pod 监控 |
| Prometheus Stats | 2 | Prometheus 自身监控 |

### 8.2 导出 Dashboard

**通过 UI**：
1. 打开 Dashboard
2. Dashboard Settings → JSON Model
3. 复制 JSON 内容
4. 保存为 `.json` 文件

### 8.3 Dashboard 版本控制

Grafana 自动保存 Dashboard 历史版本：
1. Dashboard Settings → Versions
2. 可以查看、比较、恢复历史版本

---

## 九、最佳实践

### 9.1 Dashboard 设计原则

```
1. 一目了然：重要指标放在最上面
2. 层次分明：概览 → 详情 → 明细
3. 颜色一致：绿色=正常，黄色=警告，红色=严重
4. 适当留白：不要塞满整个屏幕
```

### 9.2 Panel 设计原则

```
1. 标题清晰：一眼就知道显示什么
2. 单位正确：百分比、字节、秒等
3. 阈值合理：根据实际情况设置
4. 图例简洁：使用 {{instance}} 等模板
```

### 9.3 查询优化

```promql
# ❌ 不好：查询所有数据再过滤
sum(container_memory_working_set_bytes)

# ✅ 好：在查询时就过滤
sum(container_memory_working_set_bytes{namespace="default"})

# ❌ 不好：使用 irate 做告警（波动大）
irate(http_requests_total[5m]) > 100

# ✅ 好：使用 rate 做告警（更稳定）
rate(http_requests_total[5m]) > 100
```

---

## 十、常见问题

### Q1: Panel 显示 "No data"

**可能原因**：
1. PromQL 查询语法错误
2. 时间范围内没有数据
3. 数据源配置错误

**排查步骤**：
1. 在 Prometheus UI 中测试相同的查询
2. 检查时间范围是否正确
3. 检查数据源连接（Data Sources → Test）

### Q2: 变量不生效

**检查清单**：
1. 变量名是否正确（区分大小写）
2. 是否使用了 `$` 前缀
3. 多选变量是否使用 `=~` 而不是 `=`

**正确用法**：
```promql
# 单选变量
kube_pod_info{namespace="$namespace"}

# 多选变量
kube_pod_info{namespace=~"$namespace"}
```

### Q3: Dashboard 加载慢

**优化方法**：
1. 减少 Panel 数量（每个 Dashboard 不超过 20 个）
2. 缩短时间范围
3. 使用 `$__interval` 自动聚合
4. 使用 `instant` 查询代替范围查询

---

## 十一、金句收藏

```
"一图胜千言，一个好的 Dashboard 能让老板秒懂系统状态"

"变量是 Dashboard 的灵魂，没有变量的 Dashboard 是死的"

"颜色是最好的语言：绿色=放心，黄色=注意，红色=行动"

"Dashboard 不是越多越好，而是越清晰越好"
```

---

## 十二、学习检查清单

- [ ] 理解 Dashboard 和 Panel 的关系
- [ ] 能创建基本的 Stat、Gauge、Timeseries Panel
- [ ] 能配置变量实现动态切换
- [ ] 能设置合理的阈值和颜色
- [ ] 能导入和导出 Dashboard
- [ ] 知道如何优化 Dashboard 性能

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- Grafana 版本：10.x

---

> 📝 **下一篇**：[Exporter 详解](04-exporter-guide.md) - 了解数据采集器
