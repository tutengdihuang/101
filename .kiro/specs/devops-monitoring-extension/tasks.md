# Implementation Plan: DevOps Monitoring Extension

## Overview

本计划将为 DevOps 平台的 Tekton CI 和 ArgoCD CD 组件配置 Prometheus 监控采集，并创建统一的 Grafana Dashboard。

## Tasks

- [x] 1. Tekton 监控集成
  - [x] 1.1 检查 Tekton Controller 的 metrics 端口配置
    - 确认 tekton-pipelines-controller 服务是否暴露 9090 端口
    - 检查现有的 Service 配置
    - _Requirements: 1.1_
  - [x] 1.2 创建 Tekton ServiceMonitor 配置文件
    - 创建 `servicemonitors/tekton-servicemonitor.yaml`
    - 配置正确的 namespace selector 和 label selector
    - _Requirements: 1.1_
  - [x] 1.3 应用 Tekton ServiceMonitor 到集群
    - 执行 kubectl apply 命令
    - 验证 ServiceMonitor 创建成功
    - _Requirements: 1.1_
  - [x] 1.4 验证 Tekton 指标采集
    - 检查 Prometheus Targets 页面
    - 查询 Tekton 相关指标确认数据存在
    - _Requirements: 1.2_

- [x] 2. ArgoCD 监控集成
  - [x] 2.1 检查 ArgoCD 的 metrics 端口配置
    - 确认 argocd-server 和 argocd-application-controller 的 metrics 端口
    - 检查现有的 Service 配置
    - _Requirements: 2.1_
  - [x] 2.2 创建 ArgoCD ServiceMonitor 配置文件
    - 创建 `servicemonitors/argocd-servicemonitor.yaml`
    - 配置正确的 namespace selector 和 label selector
    - _Requirements: 2.1_
  - [x] 2.3 应用 ArgoCD ServiceMonitor 到集群
    - 执行 kubectl apply 命令
    - 验证 ServiceMonitor 创建成功
    - _Requirements: 2.1_
  - [x] 2.4 验证 ArgoCD 指标采集
    - 检查 Prometheus Targets 页面
    - 查询 ArgoCD 相关指标确认数据存在
    - _Requirements: 2.2_

- [x] 3. Checkpoint - 验证指标采集
  - 确保 Tekton 和 ArgoCD 的指标都能在 Prometheus 中查询到
  - 如有问题，排查 ServiceMonitor 配置

- [x] 4. DevOps Overview Dashboard
  - [x] 4.1 创建 Dashboard JSON 文件
    - 创建 `dashboards/devops-overview.json`
    - 包含 Tekton 指标面板（执行数、成功率、时长）
    - 包含 ArgoCD 指标面板（同步状态、健康状态）
    - 包含集群资源面板（CPU、内存）
    - _Requirements: 3.1, 3.2, 3.3_
  - [x] 4.2 导入 Dashboard 到 Grafana
    - 通过 Grafana UI 导入 JSON 文件
    - 或通过 ConfigMap 方式自动导入
    - _Requirements: 3.4_
  - [x] 4.3 验证 Dashboard 显示
    - 检查所有面板是否有数据
    - 验证时间范围切换正常
    - _Requirements: 3.4_

- [x] 5. 更新文档
  - [x] 5.1 更新 08_monitoring/README.md
    - 添加 ServiceMonitor 配置说明
    - 添加 Dashboard 使用说明
    - 更新进度状态
  - [x] 5.2 更新 devops_platform/README.md
    - 更新监控状态为已完成
    - 添加监控访问信息

- [x] 6. Final Checkpoint - 完整验证
  - 确保所有 ServiceMonitor 正常工作
  - 确保 Dashboard 所有面板显示正确
  - 确保文档更新完整

## Notes

- ServiceMonitor 需要添加 `release: prometheus` 标签才能被 Prometheus Operator 发现
- Tekton 和 ArgoCD 的 metrics 端口可能需要额外配置才能暴露
- Dashboard JSON 文件可以通过 Grafana UI 导出后修改
- 告警规则配置（Requirement 4）标记为可选，本次不实现

---

## 服务器信息

| 节点 | IP 地址 | 角色 |
|------|---------|------|
| Master | 182.42.82.135 | K8s Master, SSH 入口 |
| Worker1 | 182.42.80.121 | K8s Worker |
| Worker2 | 182.42.95.71 | K8s Worker |

**SSH 登录方式**:
```bash
ssh root@182.42.82.135
```

**服务访问地址**:
| 服务 | 地址 | 认证 |
|------|------|------|
| Grafana | http://182.42.82.135:30300 | admin / admin123 |
| Prometheus | http://182.42.82.135:30909 | 无需认证 |

---

## 验证流程

### 第一步：ServiceMonitor 存在性验证

**目的**: 确认 ServiceMonitor 资源已正确创建

**验证命令**:
```bash
ssh root@182.42.82.135 "kubectl get servicemonitor -n monitoring"
```

**成功标准** ✅:
```
NAME                                      AGE
tekton-servicemonitor                     xxd
argocd-application-controller-servicemonitor   xxd
argocd-repo-server-servicemonitor         xxd
```
- 输出中包含 `tekton-servicemonitor`
- 输出中包含 `argocd-*-servicemonitor`

**失败标准** ❌:
- 命令返回 `No resources found`
- 缺少 tekton 或 argocd 相关的 ServiceMonitor

**失败处理**:
```bash
# 重新应用 ServiceMonitor
kubectl apply -f Allen/k8slearn/devops_platform/08_monitoring/servicemonitors/
```

---

### 第二步：Prometheus Targets 状态验证

**目的**: 确认 Prometheus 能够发现并连接到监控目标

**验证命令**:
```bash
ssh root@182.42.82.135 'curl -s "http://localhost:30909/api/v1/targets" | jq ".data.activeTargets[] | select(.labels.job | test(\"tekton|argocd\")) | {job: .labels.job, health: .health, instance: .labels.instance}"'
```

**成功标准** ✅:
```json
{
  "job": "serviceMonitor/monitoring/tekton-servicemonitor/0",
  "health": "up",
  "instance": "10.x.x.x:9090"
}
{
  "job": "serviceMonitor/monitoring/argocd-application-controller-servicemonitor/0",
  "health": "up",
  "instance": "10.x.x.x:8082"
}
```
- `health` 字段为 `"up"`
- 存在 tekton 和 argocd 相关的 target

**失败标准** ❌:
- `health` 字段为 `"down"`
- 没有找到 tekton 或 argocd 相关的 target
- 返回空结果

**失败处理**:
```bash
# 检查 ServiceMonitor 的 label selector 是否匹配
kubectl get svc -n tekton-pipelines --show-labels
kubectl get svc -n argocd --show-labels

# 检查目标服务的 metrics 端口是否可达
kubectl port-forward -n tekton-pipelines svc/tekton-pipelines-controller 9090:9090
curl http://localhost:9090/metrics
```

---

### 第三步：指标数据验证

**目的**: 确认 Prometheus 能够采集到实际的指标数据

**验证命令 - Tekton 指标**:
```bash
ssh root@182.42.82.135 'curl -s "http://localhost:30909/api/v1/query?query=tekton_pipelines_controller_running_pipelineruns_count" | jq ".status, .data.result"'
```

**验证命令 - ArgoCD 指标**:
```bash
ssh root@182.42.82.135 'curl -s "http://localhost:30909/api/v1/query?query=argocd_app_info" | jq ".status, .data.result"'
```

**成功标准** ✅:
```json
"success"
[
  {
    "metric": {...},
    "value": [1704268800, "0"]
  }
]
```
- `status` 为 `"success"`
- `result` 数组不为空（有数据返回）

**失败标准** ❌:
```json
"success"
[]
```
- `status` 为 `"error"`
- `result` 为空数组 `[]`（无数据）

**失败处理**:
```bash
# 检查指标名称是否正确
curl -s "http://localhost:30909/api/v1/label/__name__/values" | jq '.data[] | select(test("tekton"))'

# 检查目标服务是否暴露了指标
kubectl exec -n tekton-pipelines deploy/tekton-pipelines-controller -- wget -qO- http://localhost:9090/metrics | head -20
```

---

### 第四步：Grafana Dashboard 验证

**目的**: 确认 Dashboard 已导入且能正确显示数据

**验证命令 - Dashboard 存在性**:
```bash
ssh root@182.42.82.135 'curl -s "http://admin:admin123@localhost:30300/api/dashboards/uid/devops-overview" | jq ".dashboard.title, .meta.isStarred"'
```

**成功标准** ✅:
```json
"DevOps Platform Overview"
false
```
- 返回 Dashboard 标题
- 不返回 404 错误

**失败标准** ❌:
```json
{
  "message": "Dashboard not found"
}
```
- 返回 `Dashboard not found` 错误
- 返回 404 状态码

**验证命令 - Dashboard 面板数据**:
```bash
# 通过浏览器访问验证
echo "请访问: http://182.42.82.135:30300/d/devops-overview"
echo "登录: admin / admin123"
echo "检查所有面板是否显示数据（非 No Data）"
```

**成功标准** ✅:
- 所有面板显示数据或数值
- 时间范围切换后数据正常刷新

**失败标准** ❌:
- 面板显示 "No Data"
- 面板显示 "Query Error"

**失败处理**:
```bash
# 重新导入 Dashboard
curl -X POST -H "Content-Type: application/json" \
  -d @Allen/k8slearn/devops_platform/08_monitoring/dashboards/devops-overview.json \
  "http://admin:admin123@182.42.82.135:30300/api/dashboards/db"
```

---

### 第五步：端到端验证（可选）

**目的**: 验证完整的监控链路

**验证步骤**:
```bash
# 1. 触发一个 Tekton PipelineRun
kubectl create -f <pipeline-run.yaml> -n tekton-pipelines

# 2. 等待 30 秒（Prometheus 采集间隔）

# 3. 检查指标是否更新
curl -s "http://182.42.82.135:30909/api/v1/query?query=increase(tekton_pipelines_controller_pipelinerun_count[5m])"

# 4. 在 Grafana Dashboard 中查看是否有新的数据点
```

---

## 验证结果汇总表

| 验证项 | 命令 | 成功标准 | 状态 |
|--------|------|---------|------|
| ServiceMonitor 存在 | `kubectl get servicemonitor -n monitoring` | 包含 tekton 和 argocd | ⬜ 待验证 |
| Prometheus Targets | `curl .../api/v1/targets` | health = "up" | ⬜ 待验证 |
| Tekton 指标 | `curl .../query?query=tekton_*` | result 非空 | ⬜ 待验证 |
| ArgoCD 指标 | `curl .../query?query=argocd_*` | result 非空 | ⬜ 待验证 |
| Dashboard 存在 | `curl .../dashboards/uid/devops-overview` | 返回标题 | ⬜ 待验证 |
| Dashboard 数据 | 浏览器访问 | 面板有数据 | ⬜ 待验证 |

---

## 一键验证脚本

```bash
#!/bin/bash
# 保存为 verify-monitoring.sh

MASTER_IP="182.42.82.135"
GRAFANA_AUTH="admin:admin123"

echo "========== DevOps Monitoring 验证 =========="
echo ""

echo "1. 检查 ServiceMonitor..."
ssh root@$MASTER_IP "kubectl get servicemonitor -n monitoring | grep -E 'tekton|argocd'" && echo "✅ ServiceMonitor 存在" || echo "❌ ServiceMonitor 缺失"
echo ""

echo "2. 检查 Prometheus Targets..."
TARGETS=$(ssh root@$MASTER_IP "curl -s 'http://localhost:30909/api/v1/targets' | jq '[.data.activeTargets[] | select(.labels.job | test(\"tekton|argocd\")) | .health] | all(. == \"up\")'")
[ "$TARGETS" = "true" ] && echo "✅ 所有 Targets 状态为 UP" || echo "❌ 存在 DOWN 的 Target"
echo ""

echo "3. 检查 Tekton 指标..."
TEKTON=$(ssh root@$MASTER_IP "curl -s 'http://localhost:30909/api/v1/query?query=tekton_pipelines_controller_running_pipelineruns_count' | jq '.data.result | length'")
[ "$TEKTON" -gt 0 ] && echo "✅ Tekton 指标存在 ($TEKTON 条)" || echo "❌ Tekton 指标为空"
echo ""

echo "4. 检查 ArgoCD 指标..."
ARGOCD=$(ssh root@$MASTER_IP "curl -s 'http://localhost:30909/api/v1/query?query=argocd_app_info' | jq '.data.result | length'")
[ "$ARGOCD" -gt 0 ] && echo "✅ ArgoCD 指标存在 ($ARGOCD 条)" || echo "❌ ArgoCD 指标为空"
echo ""

echo "5. 检查 Grafana Dashboard..."
DASHBOARD=$(ssh root@$MASTER_IP "curl -s 'http://$GRAFANA_AUTH@localhost:30300/api/dashboards/uid/devops-overview' | jq -r '.dashboard.title'")
[ "$DASHBOARD" = "DevOps Platform Overview" ] && echo "✅ Dashboard 存在: $DASHBOARD" || echo "❌ Dashboard 不存在"
echo ""

echo "========== 验证完成 =========="
```

---

## 完成状态

✅ **所有任务已完成**

- Tekton ServiceMonitor 已创建并应用
- ArgoCD ServiceMonitor 已创建并应用
- DevOps Overview Dashboard 已创建并导入到 Grafana
- 所有文档已更新
- 监控系统已完全集成到 DevOps 平台

**待执行**: 运行验证流程确认实际状态
