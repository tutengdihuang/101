# Implementation Plan: DevOps Monitoring Extension

## Overview

本计划将为 DevOps 平台的 Tekton CI 和 ArgoCD CD 组件配置 Prometheus 监控采集，并创建统一的 Grafana Dashboard。

## Tasks

- [ ] 1. Tekton 监控集成
  - [ ] 1.1 检查 Tekton Controller 的 metrics 端口配置
    - 确认 tekton-pipelines-controller 服务是否暴露 9090 端口
    - 检查现有的 Service 配置
    - _Requirements: 1.1_
  - [ ] 1.2 创建 Tekton ServiceMonitor 配置文件
    - 创建 `servicemonitors/tekton-servicemonitor.yaml`
    - 配置正确的 namespace selector 和 label selector
    - _Requirements: 1.1_
  - [ ] 1.3 应用 Tekton ServiceMonitor 到集群
    - 执行 kubectl apply 命令
    - 验证 ServiceMonitor 创建成功
    - _Requirements: 1.1_
  - [ ] 1.4 验证 Tekton 指标采集
    - 检查 Prometheus Targets 页面
    - 查询 Tekton 相关指标确认数据存在
    - _Requirements: 1.2_

- [ ] 2. ArgoCD 监控集成
  - [ ] 2.1 检查 ArgoCD 的 metrics 端口配置
    - 确认 argocd-server 和 argocd-application-controller 的 metrics 端口
    - 检查现有的 Service 配置
    - _Requirements: 2.1_
  - [ ] 2.2 创建 ArgoCD ServiceMonitor 配置文件
    - 创建 `servicemonitors/argocd-servicemonitor.yaml`
    - 配置正确的 namespace selector 和 label selector
    - _Requirements: 2.1_
  - [ ] 2.3 应用 ArgoCD ServiceMonitor 到集群
    - 执行 kubectl apply 命令
    - 验证 ServiceMonitor 创建成功
    - _Requirements: 2.1_
  - [ ] 2.4 验证 ArgoCD 指标采集
    - 检查 Prometheus Targets 页面
    - 查询 ArgoCD 相关指标确认数据存在
    - _Requirements: 2.2_

- [ ] 3. Checkpoint - 验证指标采集
  - 确保 Tekton 和 ArgoCD 的指标都能在 Prometheus 中查询到
  - 如有问题，排查 ServiceMonitor 配置

- [ ] 4. DevOps Overview Dashboard
  - [ ] 4.1 创建 Dashboard JSON 文件
    - 创建 `dashboards/devops-overview.json`
    - 包含 Tekton 指标面板（执行数、成功率、时长）
    - 包含 ArgoCD 指标面板（同步状态、健康状态）
    - 包含集群资源面板（CPU、内存）
    - _Requirements: 3.1, 3.2, 3.3_
  - [ ] 4.2 导入 Dashboard 到 Grafana
    - 通过 Grafana UI 导入 JSON 文件
    - 或通过 ConfigMap 方式自动导入
    - _Requirements: 3.4_
  - [ ] 4.3 验证 Dashboard 显示
    - 检查所有面板是否有数据
    - 验证时间范围切换正常
    - _Requirements: 3.4_

- [ ] 5. 更新文档
  - [ ] 5.1 更新 08_monitoring/README.md
    - 添加 ServiceMonitor 配置说明
    - 添加 Dashboard 使用说明
    - 更新进度状态
  - [ ] 5.2 更新 devops_platform/README.md
    - 更新监控状态为已完成
    - 添加监控访问信息

- [ ] 6. Final Checkpoint - 完整验证
  - 确保所有 ServiceMonitor 正常工作
  - 确保 Dashboard 所有面板显示正确
  - 确保文档更新完整

## Notes

- ServiceMonitor 需要添加 `release: prometheus` 标签才能被 Prometheus Operator 发现
- Tekton 和 ArgoCD 的 metrics 端口可能需要额外配置才能暴露
- Dashboard JSON 文件可以通过 Grafana UI 导出后修改
- 告警规则配置（Requirement 4）标记为可选，本次不实现
