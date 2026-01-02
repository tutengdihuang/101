# Argo Rollouts 实施设计方案

> 🎯 **目标**：为 service-test 微服务实现金丝雀发布和蓝绿部署能力

## 一、设计概览（30秒版）

**解决什么问题**：
```
现在的部署方式：
  更新镜像 → Deployment 滚动更新 → 全量切换 → 出问题只能回滚 😰

有了 Argo Rollouts：
  更新镜像 → 先切 10% 流量 → 观察指标 → 没问题再逐步放量 → 安全上线 ✅
```

**一句话精华**：
```
Argo Rollouts = 给你的发布加上"后悔药"，出问题随时能停
```

---

## 二、架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Argo Rollouts 集成架构                                │
│                                                                         │
│  开发者 git push                                                        │
│      │                                                                  │
│      ▼                                                                  │
│  Tekton CI ──▶ 构建镜像 ──▶ Harbor (v2 镜像)                            │
│      │                                                                  │
│      ▼                                                                  │
│  更新 Git 仓库中的镜像 tag (v1 → v2)                                    │
│      │                                                                  │
│      ▼                                                                  │
│  ArgoCD 检测到变化                                                       │
│      │                                                                  │
│      ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Argo Rollouts Controller                                         │   │
│  │                                                                   │   │
│  │   Rollout (替代 Deployment)                                       │   │
│  │      │                                                            │   │
│  │      ├── 金丝雀策略：10% → 30% → 50% → 100%                       │   │
│  │      │                                                            │   │
│  │      └── 或蓝绿策略：preview → 验证 → 切换 active                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│      │                                                                  │
│      ▼                                                                  │
│  服务安全上线 ✅                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 服务发布策略设计

| 服务 | 发布策略 | 理由 |
|------|----------|------|
| **web-service** | 金丝雀 (Canary) | 面向用户，需要逐步验证 |
| **user-service** | 金丝雀 (Canary) | 核心服务，需要谨慎发布 |
| **product-service** | 滚动更新 | 内部服务，风险较低 |
| **trade-service** | 滚动更新 | 内部服务，风险较低 |

**设计思路**：
- 面向用户的服务（web）和核心服务（user）使用金丝雀
- 内部服务暂时保持 Deployment，后续可按需升级

---

## 三、金丝雀发布设计

### 发布流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        金丝雀发布流程                                    │
│                                                                         │
│  阶段 1: 初始状态                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 Pod (100% 流量)                                              │   │
│  │  ████████████████████████████████████████                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  阶段 2: 金丝雀启动 (10% 流量)                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 Pod (90%)  ████████████████████████████████████              │   │
│  │  v2 Pod (10%)  ████                                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  │                                                                      │
│  │  ⏸️ 暂停 2 分钟，观察指标                                            │
│  ▼                                                                      │
│  阶段 3: 扩大金丝雀 (30% 流量)                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 Pod (70%)  ████████████████████████████                      │   │
│  │  v2 Pod (30%)  ████████████                                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  │                                                                      │
│  │  ⏸️ 暂停 2 分钟                                                      │
│  ▼                                                                      │
│  阶段 4: 继续扩大 (50% 流量)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 Pod (50%)  ████████████████████                              │   │
│  │  v2 Pod (50%)  ████████████████████                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  │                                                                      │
│  │  ⏸️ 暂停 2 分钟                                                      │
│  ▼                                                                      │
│  阶段 5: 全量发布 (100% 流量)                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v2 Pod (100%)                                                   │   │
│  │  ████████████████████████████████████████                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ✅ 发布完成！                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### web-service 金丝雀配置

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-service
  namespace: service-test
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: web-service
  strategy:
    canary:
      # 金丝雀步骤
      steps:
      - setWeight: 10          # 10% 流量到新版本
      - pause: {duration: 2m}  # 暂停 2 分钟观察
      - setWeight: 30          # 30% 流量
      - pause: {duration: 2m}
      - setWeight: 50          # 50% 流量
      - pause: {duration: 2m}
      - setWeight: 100         # 全量发布
      
      # 流量管理（可选，需要 Istio/Nginx Ingress）
      # trafficRouting:
      #   nginx:
      #     stableIngress: web-ingress
  template:
    # ... Pod 模板（与原 Deployment 相同）
```

---

## 四、目录结构设计

```
05_argo_rollouts/
├── README.md                           # 说明文档
├── DESIGN.md                           # 本设计文档
├── TUTORIAL.md                         # 深入浅出教程
│
├── install/
│   ├── 01-namespace.yaml               # argo-rollouts namespace
│   ├── 02-argo-rollouts-install.yaml   # Argo Rollouts 安装
│   └── 03-dashboard.yaml               # Rollouts Dashboard（可选）
│
├── rollouts/
│   ├── web-service-rollout.yaml        # web-service 金丝雀配置
│   └── user-service-rollout.yaml       # user-service 金丝雀配置
│
└── examples/
    ├── canary-basic.yaml               # 基础金丝雀示例
    ├── canary-with-analysis.yaml       # 带自动分析的金丝雀
    └── bluegreen-basic.yaml            # 蓝绿部署示例
```

---

## 五、实施步骤

### 阶段 1: 安装 Argo Rollouts

```bash
# 1. 创建 namespace
kubectl create namespace argo-rollouts

# 2. 安装 Argo Rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 3. 验证安装
kubectl get pods -n argo-rollouts

# 4. 安装 kubectl 插件（可选但推荐）
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### 阶段 2: 迁移 web-service

```bash
# 1. 备份现有 Deployment
kubectl get deployment web-service -n service-test -o yaml > web-service-backup.yaml

# 2. 删除现有 Deployment（ArgoCD 会自动处理）
# 注意：先更新 Git 仓库中的配置

# 3. 应用 Rollout 配置
kubectl apply -f rollouts/web-service-rollout.yaml

# 4. 验证
kubectl argo rollouts get rollout web-service -n service-test
```

### 阶段 3: 测试金丝雀发布

```bash
# 1. 更新镜像触发金丝雀
kubectl argo rollouts set image web-service web=182.42.82.135:30002/service-test/web-service:v2 -n service-test

# 2. 观察发布进度
kubectl argo rollouts get rollout web-service -n service-test --watch

# 3. 手动推进（如果配置了 pause 无时间限制）
kubectl argo rollouts promote web-service -n service-test

# 4. 如果发现问题，中止发布
kubectl argo rollouts abort web-service -n service-test

# 5. 回滚到上一版本
kubectl argo rollouts undo web-service -n service-test
```

---

## 六、与现有系统集成

### ArgoCD 集成

ArgoCD 原生支持 Argo Rollouts，无需额外配置：

```
Git 仓库更新 Rollout 配置
    │
    ▼
ArgoCD 检测到变化
    │
    ▼
ArgoCD 同步 Rollout 资源
    │
    ▼
Argo Rollouts Controller 执行金丝雀策略
```

### Git 仓库结构调整

```
k8s/
├── configmaps.yaml
├── namespace.yaml
├── user/
│   └── rollout.yaml          # 替换 deployment.yaml
├── product/
│   └── deployment.yaml       # 保持不变
├── trade/
│   └── deployment.yaml       # 保持不变
└── web/
    └── rollout.yaml          # 替换 deployment.yaml
```

---

## 七、监控与可观测性

### Rollouts Dashboard

```bash
# 安装 Dashboard
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml

# 暴露 Dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

# 或者创建 NodePort Service
```

### 关键指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| 错误率 | 新版本的 5xx 错误率 | > 5% 自动回滚 |
| 延迟 | P99 响应时间 | > 500ms 告警 |
| 成功率 | 请求成功率 | < 95% 自动回滚 |

---

## 八、风险与回滚

### 自动回滚条件

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 2m}
    # 可以配置 Analysis 自动检测指标
    # - analysis:
    #     templates:
    #     - templateName: success-rate
    #     args:
    #     - name: service-name
    #       value: web-service
```

### 手动回滚

```bash
# 中止当前发布
kubectl argo rollouts abort web-service -n service-test

# 回滚到上一版本
kubectl argo rollouts undo web-service -n service-test

# 回滚到指定版本
kubectl argo rollouts undo web-service --to-revision=2 -n service-test
```

---

## 九、实施计划

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 安装 Argo Rollouts | 10 分钟 |
| 2 | 创建 web-service Rollout 配置 | 15 分钟 |
| 3 | 迁移 web-service 到 Rollout | 10 分钟 |
| 4 | 测试金丝雀发布 | 20 分钟 |
| 5 | 创建 user-service Rollout 配置 | 10 分钟 |
| 6 | 编写教程文档 | 30 分钟 |

**总计**：约 1.5 小时

---

## 十、预期效果

**实施前**：
```
更新镜像 → 全量滚动更新 → 出问题才发现 → 紧急回滚 😰
```

**实施后**：
```
更新镜像 → 10% 金丝雀 → 观察指标 → 没问题继续 → 安全上线 ✅
           │
           └── 发现问题 → 立即中止 → 只影响 10% 用户
```

---

## 十一、后续优化

1. **集成 Prometheus**：自动分析指标，实现自动回滚
2. **集成 Istio**：更精细的流量控制
3. **添加 Analysis**：自动化金丝雀验证
4. **蓝绿部署**：为关键服务提供蓝绿选项

---

*设计版本：v1.0 | 设计日期：2026-01-02*
