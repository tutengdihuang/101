# Argo Rollouts 深入浅出教程

> 🎯 **一句话定位**：Argo Rollouts 让你的发布有"后悔药"，出问题随时能停。

## 秒懂 Argo Rollouts（30秒版）

**解决什么问题**：
```
传统 Deployment 滚动更新：
  更新镜像 → 全量替换 → 出问题才发现 → 紧急回滚 😰

Argo Rollouts 金丝雀发布：
  更新镜像 → 先切 10% 流量 → 观察指标 → 没问题再放量 → 安全上线 ✅
```

**一句话精华**：
```
Argo Rollouts = Deployment 的升级版，支持金丝雀和蓝绿发布
```

**适合谁学**：已经会 K8s Deployment，想实现安全发布的开发者
**不适合谁**：完全不懂 K8s 的新手（先学 Deployment）

---

## 核心概念（用生活比喻理解）

### 发布策略对比

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        三种发布策略对比                                  │
│                                                                         │
│  【滚动更新】Deployment 默认                                             │
│  就像：换灯泡，一个一个换，换完一个再换下一个                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 v1 v1 v1 → v2 v1 v1 v1 → v2 v2 v1 v1 → v2 v2 v2 v1 → v2 v2 v2 v2│
│  └─────────────────────────────────────────────────────────────────┘   │
│  优点：简单                                                              │
│  缺点：出问题时已经影响了部分用户                                         │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  【金丝雀发布】Canary                                                    │
│  就像：新菜品先让 10% 顾客试吃，反馈好再推广                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  v1 (90%) ████████████████████████████████████                   │   │
│  │  v2 (10%) ████                                                   │   │
│  │           ↓ 观察 2 分钟，没问题                                   │   │
│  │  v1 (70%) ████████████████████████████                           │   │
│  │  v2 (30%) ████████████                                           │   │
│  │           ↓ 继续观察...                                           │   │
│  │  v2 (100%) ████████████████████████████████████████              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  优点：风险可控，出问题只影响小部分用户                                   │
│  缺点：发布时间较长                                                      │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  【蓝绿部署】Blue-Green                                                  │
│  就像：新店装修好了，一键切换，老店关门                                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  蓝 (v1) ◀── 当前流量                                            │   │
│  │  绿 (v2) ◀── 新版本就绪，等待切换                                 │   │
│  │           ↓ 验证通过，一键切换                                    │   │
│  │  蓝 (v1)     旧版本，保留用于回滚                                 │   │
│  │  绿 (v2) ◀── 当前流量                                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│  优点：切换快，回滚也快                                                  │
│  缺点：需要双倍资源                                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 概念速查表

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| **Rollout** | 替代 Deployment 的资源 | 升级版的部署方案 |
| **Canary** | 金丝雀发布策略 | 新菜品先让少数人试吃 |
| **Blue-Green** | 蓝绿部署策略 | 新店装修好一键切换 |
| **setWeight** | 设置流量比例 | 决定多少顾客吃新菜 |
| **pause** | 暂停观察 | 等等看顾客反馈 |
| **promote** | 推进发布 | 反馈好，继续推广 |
| **abort** | 中止发布 | 反馈差，停止推广 |

---

## 从项目理解 Argo Rollouts

### Rollout vs Deployment

**Deployment（原来的）**：
```yaml
apiVersion: apps/v1
kind: Deployment          # 👈 资源类型
metadata:
  name: web-service
spec:
  replicas: 3
  # 没有 strategy.canary，只有滚动更新
  template:
    # ...
```

**Rollout（升级后）**：
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout            # 👈 资源类型变了
metadata:
  name: web-service
spec:
  replicas: 3
  strategy:
    canary:              # 👈 新增：金丝雀策略
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 30
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 100
  template:
    # ... 和 Deployment 一样
```

**关键区别**：
```
Deployment：
  apiVersion: apps/v1
  kind: Deployment
  strategy: RollingUpdate（默认）

Rollout：
  apiVersion: argoproj.io/v1alpha1
  kind: Rollout
  strategy: canary 或 blueGreen
```

### 金丝雀步骤详解

```yaml
strategy:
  canary:
    steps:
    # 步骤1：切 10% 流量到新版本
    - setWeight: 10
    
    # 步骤2：暂停 2 分钟，观察指标
    - pause: {duration: 2m}
    
    # 步骤3：没问题，切 30% 流量
    - setWeight: 30
    
    # 步骤4：再观察 2 分钟
    - pause: {duration: 2m}
    
    # 步骤5：切 50% 流量
    - setWeight: 50
    
    # 步骤6：再观察 2 分钟
    - pause: {duration: 2m}
    
    # 步骤7：全量发布
    - setWeight: 100
```

**生活比喻**：
```
新菜品上市流程：
1. 先让 10% 顾客试吃（setWeight: 10）
2. 等 2 分钟看反馈（pause: 2m）
3. 反馈好，让 30% 顾客吃（setWeight: 30）
4. 再等 2 分钟（pause: 2m）
5. 继续扩大到 50%（setWeight: 50）
6. 再观察（pause: 2m）
7. 全面推广（setWeight: 100）
```

### pause 的两种用法

```yaml
# 用法1：定时暂停（自动继续）
- pause: {duration: 2m}    # 暂停 2 分钟后自动继续

# 用法2：无限暂停（需要手动 promote）
- pause: {}                # 暂停，等待手动确认
```

**什么时候用哪种？**
```
定时暂停：开发/测试环境，自动化发布
无限暂停：生产环境，需要人工确认
```

---

## 实际操作指南

### 1. 查看 Rollout 状态

```bash
# 查看所有 Rollout
kubectl get rollouts -n service-test

# 查看详细状态（推荐用插件）
kubectl argo rollouts get rollout web-service -n service-test

# 实时观察发布进度
kubectl argo rollouts get rollout web-service -n service-test --watch
```

**状态输出示例**：
```
Name:            web-service
Namespace:       service-test
Status:          ॥ Paused
Strategy:        Canary
  Step:          2/7
  SetWeight:     10
  ActualWeight:  10
Images:          182.42.82.135:30002/service-test/web-service:v1 (stable)
                 182.42.82.135:30002/service-test/web-service:v2 (canary)
Replicas:
  Desired:       3
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3
```

### 2. 触发金丝雀发布

```bash
# 方式1：更新镜像
kubectl argo rollouts set image web-service \
  web=182.42.82.135:30002/service-test/web-service:v2 \
  -n service-test

# 方式2：修改 Git 仓库中的镜像 tag，ArgoCD 自动同步
```

### 3. 手动推进发布

```bash
# 推进到下一步（当 pause: {} 时需要）
kubectl argo rollouts promote web-service -n service-test

# 跳过所有步骤，直接全量发布
kubectl argo rollouts promote web-service --full -n service-test
```

### 4. 中止发布

```bash
# 发现问题，中止发布
kubectl argo rollouts abort web-service -n service-test

# 中止后，流量会回到稳定版本
```

### 5. 回滚

```bash
# 回滚到上一版本
kubectl argo rollouts undo web-service -n service-test

# 回滚到指定版本
kubectl argo rollouts undo web-service --to-revision=2 -n service-test
```

---

## 发布流程图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        金丝雀发布完整流程                                │
│                                                                         │
│  1. 更新镜像（触发发布）                                                 │
│     kubectl argo rollouts set image web-service web=xxx:v2              │
│         │                                                               │
│         ▼                                                               │
│  2. 创建金丝雀 Pod                                                       │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │  Stable (v1): 3 个 Pod                                       │    │
│     │  Canary (v2): 1 个 Pod（10% 流量）                           │    │
│     └─────────────────────────────────────────────────────────────┘    │
│         │                                                               │
│         ▼                                                               │
│  3. 暂停观察（pause: 2m）                                               │
│     │                                                                   │
│     ├── 指标正常 → 自动继续（或手动 promote）                           │
│     │                                                                   │
│     └── 发现问题 → 手动 abort → 回滚到 v1                               │
│         │                                                               │
│         ▼                                                               │
│  4. 逐步增加流量                                                        │
│     10% → 30% → 50% → 100%                                             │
│         │                                                               │
│         ▼                                                               │
│  5. 发布完成                                                            │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │  Stable (v2): 3 个 Pod（100% 流量）                          │    │
│     │  旧版本 Pod 已清理                                           │    │
│     └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 常见问题 FAQ

### Q1: Rollout 和 Deployment 能共存吗？

```
可以！它们是不同的资源类型。

但同一个服务不要同时用两种，会冲突。
迁移时：先删 Deployment，再创建 Rollout。
```

### Q2: 金丝雀发布时，流量是怎么分配的？

```
默认：通过 Pod 数量比例分配

例如：3 个 v1 Pod + 1 个 v2 Pod = 25% 流量到 v2

更精确的流量控制需要配合：
- Istio
- Nginx Ingress
- AWS ALB
```

### Q3: 发布过程中可以修改步骤吗？

```
可以！修改 Rollout 的 strategy.canary.steps 即可。

但正在进行的发布会重新开始。
```

### Q4: 如何实现自动回滚？

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - analysis:                    # 自动分析
        templates:
        - templateName: success-rate
    - setWeight: 50
    - analysis:
        templates:
        - templateName: success-rate

# 需要配合 AnalysisTemplate 和 Prometheus
# 后续可以添加这个功能
```

### Q5: 蓝绿部署和金丝雀怎么选？

```
金丝雀：
- 适合：需要逐步验证的场景
- 优点：风险可控，影响范围小
- 缺点：发布时间长

蓝绿：
- 适合：需要快速切换的场景
- 优点：切换快，回滚也快
- 缺点：需要双倍资源
```

---

## 与 ArgoCD 集成

### 工作流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ArgoCD + Argo Rollouts 集成                          │
│                                                                         │
│  1. 开发者更新 Git 仓库中的镜像 tag                                      │
│         │                                                               │
│         ▼                                                               │
│  2. ArgoCD 检测到变化                                                    │
│         │                                                               │
│         ▼                                                               │
│  3. ArgoCD 同步 Rollout 资源                                            │
│         │                                                               │
│         ▼                                                               │
│  4. Argo Rollouts Controller 执行金丝雀策略                              │
│         │                                                               │
│         ├── setWeight: 10                                               │
│         ├── pause: 2m                                                   │
│         ├── setWeight: 30                                               │
│         ├── ...                                                         │
│         ▼                                                               │
│  5. 发布完成                                                            │
└─────────────────────────────────────────────────────────────────────────┘
```

### ArgoCD UI 中的显示

ArgoCD 原生支持 Rollout 资源，会显示：
- Rollout 状态（Healthy/Progressing/Degraded）
- 当前步骤
- Pod 版本分布

---

## 命令速查表

```bash
# === 查看状态 ===
kubectl argo rollouts list rollouts -n service-test
kubectl argo rollouts get rollout web-service -n service-test
kubectl argo rollouts get rollout web-service -n service-test --watch

# === 触发发布 ===
kubectl argo rollouts set image web-service web=xxx:v2 -n service-test

# === 控制发布 ===
kubectl argo rollouts promote web-service -n service-test      # 推进
kubectl argo rollouts promote web-service --full -n service-test  # 全量
kubectl argo rollouts abort web-service -n service-test        # 中止
kubectl argo rollouts retry rollout web-service -n service-test   # 重试

# === 回滚 ===
kubectl argo rollouts undo web-service -n service-test
kubectl argo rollouts undo web-service --to-revision=2 -n service-test

# === 查看历史 ===
kubectl argo rollouts history web-service -n service-test
```

---

## 金句总结

```
📌 Argo Rollouts 的本质：
   "给 Deployment 加上金丝雀和蓝绿发布能力"

📌 核心概念记忆：
   Rollout = 升级版 Deployment
   setWeight = 设置流量比例
   pause = 暂停观察
   promote = 推进发布
   abort = 中止发布

📌 发布策略选择：
   金丝雀 = 逐步放量，风险可控
   蓝绿 = 一键切换，快速回滚

📌 一句话带走：
   "Argo Rollouts 让你的发布有后悔药，出问题随时能停"
```

---

## 延伸学习

**想深入学习**：
- [Argo Rollouts 官方文档](https://argoproj.github.io/argo-rollouts/)
- [金丝雀发布最佳实践](https://argoproj.github.io/argo-rollouts/features/canary/)

**下一步**：
- 集成 Prometheus 实现自动分析
- 配置 Analysis 自动回滚
- 尝试蓝绿部署

---

*文档版本：v1.0 | 更新日期：2026-01-02 | 基于项目：service-test CI/CD*
