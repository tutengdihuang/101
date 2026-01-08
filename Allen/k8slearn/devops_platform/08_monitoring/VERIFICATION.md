# 监控系统验证文档

## 服务器信息

### Master 节点
- **外网 IP**: 182.42.82.135
- **内网 IP**: 10.0.3.231
- **SSH 登录**: `ssh root@182.42.82.135`
- **密码**: 1Qaz2Wsx

### Worker 节点
- **节点 1**:
  - 外网 IP: 182.42.80.121
  - 内网 IP: 10.0.1.149
  - SSH 登录: `ssh root@182.42.80.121`
- **节点 2**:
  - 外网 IP: 182.42.95.71
  - 内网 IP: 10.0.0.32
  - SSH 登录: `ssh root@182.42.95.71`

### 服务访问地址
- **Prometheus**: http://182.42.82.135:30090
- **Grafana**: http://182.42.82.135:30080
  - 默认用户名: admin
  - 默认密码: admin

## 验证流程

### 步骤 1: ServiceMonitor 存在性验证

**目的**: 验证 Tekton 和 ArgoCD 的 ServiceMonitor 资源是否已创建

**验证命令**:
```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get servicemonitors -n monitoring'
```

**成功标准**:
- 输出包含 `tekton-servicemonitor`
- 输出包含 `argocd-servicemonitor`
- 两个 ServiceMonitor 的状态都为 `Ready`

**失败处理**:
- 如果 ServiceMonitor 不存在，执行：
  ```bash
  kubectl apply -f servicemonitors/tekton-servicemonitor.yaml
  kubectl apply -f servicemonitors/argocd-servicemonitor.yaml
  ```
- 如果状态不是 Ready，检查 ServiceMonitor 的 label 是否正确（必须包含 `release: prometheus`）

### 步骤 2: Prometheus Targets 状态验证

**目的**: 验证 Prometheus 是否成功发现并抓取 Tekton 和 ArgoCD 的指标端点

**验证命令**:
```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name | head -1 | xargs -I {} kubectl exec -n monitoring {} -- wget -qO- http://localhost:9090/api/v1/targets | python3 -m json.tool'
```

**成功标准**:
- 输出包含 Tekton 相关的 target（job 名称包含 `tekton`）
- 输出包含 ArgoCD 相关的 target（job 名称包含 `argocd`）
- 所有相关 target 的健康状态为 `up`

**失败处理**:
- 如果 target 不存在，检查 ServiceMonitor 的 namespace selector 和 label selector 配置
- 如果 target 状态为 down，检查：
  - Service 的端口配置是否正确
  - Pod 是否正常运行
  - 网络策略是否阻止了访问

### 步骤 3: 指标数据验证（Tekton + ArgoCD）

**目的**: 验证 Prometheus 中是否存在 Tekton 和 ArgoCD 的指标数据

**验证命令**:

Tekton 指标验证：
```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name | head -1 | xargs -I {} kubectl exec -n monitoring {} -- wget -qO- "http://localhost:9090/api/v1/query?query=up{job=~\".*tekton.*\"}" | python3 -m json.tool'
```

ArgoCD 指标验证：
```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name | head -1 | xargs -I {} kubectl exec -n monitoring {} -- wget -qO- "http://localhost:9090/api/v1/query?query=up{job=~\".*argocd.*\"}" | python3 -m json.tool'
```

**成功标准**:
- Tekton 查询返回至少一个结果，且 `metric.value[1]` 为 `1`
- ArgoCD 查询返回至少一个结果，且 `metric.value[1]` 为 `1`

**失败处理**:
- 如果没有数据，检查 Prometheus 是否正在抓取指标
- 如果指标值为 0，检查目标服务是否正常运行
- 等待 1-2 分钟后重新验证（指标采集可能有延迟）

### 步骤 4: Grafana Dashboard 验证

**目的**: 验证 DevOps Overview Dashboard 是否已正确导入并显示数据

**验证命令**:
```bash
sshpass -p '1Qaz2Wsx' ssh -o StrictHostKeyChecking=no root@182.42.82.135 'curl -s http://admin:admin@localhost:30080/api/search?query=DevOps | python3 -m json.tool'
```

**成功标准**:
- 输出包含标题为 "DevOps Platform Overview" 的 dashboard
- Dashboard 的 uid 或 id 存在

**失败处理**:
- 如果 Dashboard 不存在，重新导入：
  ```bash
  kubectl port-forward -n monitoring svc/grafana 30080:80
  curl -X POST http://admin:admin@localhost:30080/api/dashboards/db -H "Content-Type: application/json" -d @dashboards/devops-overview.json
  ```

### 步骤 5: 端到端验证（可选）

**目的**: 验证从数据采集到可视化展示的完整流程

**验证步骤**:
1. 在浏览器访问 Grafana: http://182.42.82.135:30080
2. 登录（admin/admin）
3. 打开 "DevOps Overview" Dashboard
4. 检查所有面板是否显示数据
5. 切换时间范围，验证数据更新

**成功标准**:
- 所有面板都有数据显示
- 时间范围切换后数据正常更新
- 没有 "No Data" 或 "N/A" 错误

**失败处理**:
- 如果某些面板无数据，检查面板的查询语句是否正确
- 如果时间范围切换有问题，检查 Prometheus 的数据保留配置
- 查看浏览器控制台是否有错误信息

## 验证结果汇总表

| 验证项 | 状态 | 备注 |
|--------|------|------|
| ServiceMonitor 存在性 | ✅ 通过 | Tekton 和 ArgoCD ServiceMonitor 都存在 |
| Prometheus Targets 状态 | ✅ 通过 | 20 个 Tekton Target，14 个 ArgoCD Target |
| Tekton 指标数据 | ✅ 通过 | 指标数据正常采集 |
| ArgoCD 指标数据 | ✅ 通过 | 指标数据正常采集 |
| Grafana Dashboard | ✅ 通过 | DevOps Platform Overview Dashboard 已导入 |

**验证日期**: 2026-01-03
**验证结果**: 7/7 通过

## 一键验证脚本

使用 `verify-monitoring.sh` 脚本可以自动化执行所有验证步骤：

```bash
./verify-monitoring.sh
```

脚本会自动：
1. 验证 ServiceMonitor 存在性
2. 验证 Prometheus Targets 状态
3. 验证指标数据
4. 验证 Grafana Dashboard
5. 生成验证报告

### 最新验证结果

**验证日期**: 2026-01-03
**验证结果**: ✅ 所有验证通过（7/7）

```
[INFO] =========================================
[INFO] 监控系统一键验证脚本
[INFO] =========================================

[INFO] 步骤 1: 验证 ServiceMonitor 存在性
[INFO] ✓ Tekton ServiceMonitor 存在
[INFO] ✓ ArgoCD ServiceMonitor 存在

[INFO] 步骤 2: 验证 Prometheus Targets 状态
[INFO] Prometheus Pod: prometheus-prometheus-kube-prometheus-prometheus-0
[INFO] ✓ 找到       20 个 Tekton 相关的 Target
[INFO] ✓ 找到       14 个 ArgoCD 相关的 Target

[INFO] 步骤 3: 验证 Tekton 指标数据
[INFO] ✓ Tekton 指标数据存在

[INFO] 步骤 4: 验证 ArgoCD 指标数据
[INFO] ✓ ArgoCD 指标数据存在

[INFO] 步骤 5: 验证 Grafana Dashboard
[INFO] ✓ DevOps Platform Overview Dashboard 存在

[INFO] =========================================
[INFO] 验证报告
[INFO] =========================================

[INFO] 通过: 7
[INFO] 失败: 0

[INFO] ✓ 所有验证通过！
```

## 常见问题排查

### ServiceMonitor 不被 Prometheus 发现
- 检查 ServiceMonitor 是否有 `release: prometheus` 标签
- 检查 Prometheus Operator 的 serviceMonitorSelector 配置

### Prometheus Target 状态为 down
- 检查目标 Pod 是否正常运行
- 检查 Service 的端口配置是否正确
- 检查网络策略是否允许访问

### Grafana Dashboard 无数据
- 检查 Prometheus 数据源配置
- 检查 Dashboard 的查询语句
- 确认时间范围设置合理

### 指标采集延迟
- Prometheus 默认抓取间隔为 30 秒
- 等待 1-2 分钟后重新验证
- 检查 Prometheus 的存储配置
