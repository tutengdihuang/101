# 监控系统文档索引

> 📚 Prometheus + Grafana + AlertManager 监控体系完整文档

## 文档结构

```
documents/
├── docs/                    # 📖 学习文档（知识点）
│   ├── 01-monitoring-overview.md      # 监控体系概述
│   ├── 02-prometheus-basics.md        # Prometheus 基础
│   ├── 03-grafana-basics.md           # Grafana 基础
│   ├── 04-exporter-guide.md           # Exporter 详解
│   ├── 05-servicemonitor-guide.md     # ServiceMonitor 配置
│   ├── 06-alertmanager-guide.md       # AlertManager 告警系统
│   ├── 07-prometheusrule-guide.md     # 告警规则编写
│   ├── 08-pod-monitoring.md           # Pod 监控机制
│   └── 09-promql-cookbook.md          # PromQL 查询手册
│
└── guides/                  # 🔧 操作指南（实践操作）
    ├── installation.md                # 安装部署指南
    ├── add-servicemonitor.md          # 添加监控目标
    ├── create-dashboard.md            # 创建 Dashboard
    ├── create-alert-rule.md           # 创建告警规则
    ├── silence-alerts.md              # 告警静默操作
    └── troubleshooting.md             # 故障排查指南
```

---

## 📖 学习文档

### 入门篇

| 文档 | 说明 | 适合谁 |
|------|------|--------|
| [01-监控体系概述](docs/01-monitoring-overview.md) | 监控架构全景图、组件关系、数据流 | 刚接触监控的同学 |
| [02-Prometheus 基础](docs/02-prometheus-basics.md) | 数据模型、指标类型、PromQL 入门 | 想了解 Prometheus 的同学 |
| [03-Grafana 基础](docs/03-grafana-basics.md) | 数据源、Dashboard、Panel、变量 | 想学习可视化的同学 |

### 进阶篇

| 文档 | 说明 | 适合谁 |
|------|------|--------|
| [04-Exporter 详解](docs/04-exporter-guide.md) | Node/KSM/Kubelet 等 Exporter | 想深入了解指标采集的同学 |
| [05-ServiceMonitor 配置](docs/05-servicemonitor-guide.md) | ServiceMonitor/PodMonitor 配置 | 需要添加监控目标的同学 |
| [06-AlertManager 告警系统](docs/06-alertmanager-guide.md) | 告警流程、路由、静默、抑制 | 需要配置告警的同学 |
| [07-告警规则编写](docs/07-prometheusrule-guide.md) | PrometheusRule 编写最佳实践 | 需要编写告警规则的同学 |
| [08-Pod 监控机制](docs/08-pod-monitoring.md) | cAdvisor、资源指标、健康检查 | 想了解 Pod 监控原理的同学 |

### 工具篇

| 文档 | 说明 | 适合谁 |
|------|------|--------|
| [09-PromQL 查询手册](docs/09-promql-cookbook.md) | 常用 PromQL 查询示例集 | 所有需要查询指标的同学 |

---

## 🔧 操作指南

| 文档 | 说明 | 使用场景 |
|------|------|---------|
| [安装部署指南](guides/installation.md) | 完整安装步骤、镜像配置 | 首次部署监控系统 |
| [添加监控目标](guides/add-servicemonitor.md) | 添加新 ServiceMonitor 的步骤 | 扩展监控范围 |
| [创建 Dashboard](guides/create-dashboard.md) | 创建自定义 Grafana Dashboard | 定制可视化面板 |
| [创建告警规则](guides/create-alert-rule.md) | 创建 PrometheusRule 的步骤 | 配置告警 |
| [告警静默操作](guides/silence-alerts.md) | 创建静默规则 | 维护期间屏蔽告警 |
| [故障排查指南](guides/troubleshooting.md) | 常见问题排查 | 遇到问题时查阅 |

---

## 学习路径推荐

### 🚀 快速上手（1小时）

1. [01-监控体系概述](docs/01-monitoring-overview.md) - 了解整体架构
2. [安装部署指南](guides/installation.md) - 部署监控系统
3. 访问 Grafana 查看内置 Dashboard

### 📈 深入学习（1天）

1. [02-Prometheus 基础](docs/02-prometheus-basics.md) - 理解数据模型
2. [03-Grafana 基础](docs/03-grafana-basics.md) - 学习可视化
3. [09-PromQL 查询手册](docs/09-promql-cookbook.md) - 掌握查询语言
4. [创建 Dashboard](guides/create-dashboard.md) - 动手实践

### 🔔 告警配置（半天）

1. [06-AlertManager 告警系统](docs/06-alertmanager-guide.md) - 理解告警流程
2. [07-告警规则编写](docs/07-prometheusrule-guide.md) - 学习规则编写
3. [创建告警规则](guides/create-alert-rule.md) - 动手实践

### 🔧 运维进阶（持续）

1. [04-Exporter 详解](docs/04-exporter-guide.md) - 深入指标采集
2. [05-ServiceMonitor 配置](docs/05-servicemonitor-guide.md) - 扩展监控
3. [08-Pod 监控机制](docs/08-pod-monitoring.md) - 理解 Pod 监控
4. [故障排查指南](guides/troubleshooting.md) - 问题处理

---

## 当前环境信息

| 服务 | 地址 | 说明 |
|------|------|------|
| Grafana | http://182.42.82.135:30300 | admin / admin123 |
| Prometheus | http://182.42.82.135:30909 | 指标查询 |
| AlertManager | http://182.42.82.135:30903 | 告警管理 |

---

## 版本信息

- 文档版本：v2.0
- 更新日期：2026-01-05
- Prometheus：v3.2.1
- Grafana：v10.4.2
- AlertManager：v0.27.0
- kube-prometheus-stack：v72.6.2
