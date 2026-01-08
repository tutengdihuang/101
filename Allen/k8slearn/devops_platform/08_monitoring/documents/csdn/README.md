# Kubernetes 监控系统完全指南

> 🎯 从零到精通，一站式掌握 Prometheus + Grafana + AlertManager 监控体系

## 📚 文档目录

### 基础概念篇

| 序号 | 文档 | 说明 |
|------|------|------|
| 01 | [监控系统概述](01-monitoring-overview.md) | 监控体系全景图，理解各组件关系 |
| 02 | [Prometheus 基础](02-prometheus-basics.md) | 时序数据库核心概念和架构 |
| 03 | [Grafana 基础](03-grafana-basics.md) | 可视化平台入门指南 |
| 04 | [Exporter 指南](04-exporter-guide.md) | 指标采集器详解 |

### 核心配置篇

| 序号 | 文档 | 说明 |
|------|------|------|
| 05 | [ServiceMonitor 指南](05-servicemonitor-guide.md) | 服务发现配置详解 |
| 06 | [AlertManager 指南](06-alertmanager-guide.md) | 告警管理系统详解 |
| 07 | [PrometheusRule 指南](07-prometheusrule-guide.md) | 告警规则配置详解 |

### 进阶实战篇

| 序号 | 文档 | 说明 |
|------|------|------|
| 08 | [Pod 监控机制](08-pod-monitoring.md) | 深入理解容器监控原理 |
| 09 | [PromQL 查询手册](09-promql-cookbook.md) | 常用查询示例集 |
| 10 | [CI/CD 监控指南](10-cicd-monitoring.md) | Tekton + ArgoCD 监控实战 |

### 操作指南篇

| 文档 | 说明 |
|------|------|
| [安装部署指南](guides/installation.md) | 从零搭建监控栈 |
| [添加监控目标](guides/add-servicemonitor.md) | 配置 ServiceMonitor |
| [创建告警规则](guides/create-alert-rule.md) | 配置 PrometheusRule |
| [创建 Dashboard](guides/create-dashboard.md) | Grafana 面板设计 |
| [告警静默操作](guides/silence-alerts.md) | 维护期间屏蔽告警 |
| [故障排查指南](guides/troubleshooting.md) | 常见问题解决方案 |

---

## 🎯 学习路径推荐

### 入门路径（2-3 小时）

```
01-监控概述 → 02-Prometheus基础 → 03-Grafana基础 → guides/installation
```

### 进阶路径（4-6 小时）

```
04-Exporter → 05-ServiceMonitor → 06-AlertManager → 07-PrometheusRule → 10-CI/CD监控
```

### 实战路径（按需）

```
08-Pod监控 → 09-PromQL手册 → guides/troubleshooting
```

---

## 📝 文档特点

- ✅ **脱敏处理**：所有敏感信息已替换为占位符
- ✅ **深入浅出**：复杂概念用生活化比喻解释
- ✅ **金句收藏**：每篇文档都有精华总结
- ✅ **实战导向**：提供可直接使用的配置示例
- ✅ **问题排查**：包含常见问题和解决方案

---

## 🔗 系列导航

每篇文档底部都有系列导航，方便按顺序阅读。

---

## 📅 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：Kubernetes 1.25+, kube-prometheus-stack

---

> 💡 **提示**：建议按照学习路径顺序阅读，效果更佳！
