# Argo Rollouts 用户指南

> 🎯 让发布像"试吃"一样安全 —— 金丝雀发布实战指南

---

## 一句话理解

**金丝雀发布就像餐厅试菜**：新菜品先让 10% 的顾客试吃，反馈好再扩大到 30%、50%，最后全面上架。如果有人说不好吃，立刻撤回，不影响其他顾客。

---

## 为什么需要金丝雀发布？

### 传统发布的痛点

```
传统发布 = 一次性全量更新
         ↓
    出问题 = 全部用户受影响
         ↓
    回滚 = 手忙脚乱
```

### 金丝雀发布的优势

```
金丝雀发布 = 逐步放量
         ↓
    出问题 = 只影响小部分用户
         ↓
    回滚 = 一键搞定，优雅从容
```

**生活化比喻**：
- 传统发布 = 新药直接全民推广（风险巨大）
- 金丝雀发布 = 新药先临床试验，再小范围推广，最后全面上市（安全可控）

---

## 核心概念速查

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| **Rollout** | 替代 Deployment 的发布控制器 | 升级版的"发布管家" |
| **Canary（金丝雀）** | 新版本的小规模测试 | 矿井里的金丝雀，先探路 |
| **Stable** | 当前稳定运行的版本 | 正在营业的老店 |
| **Promote** | 推进发布到下一阶段 | 给新菜品"转正" |
| **Abort** | 中止发布，回滚到稳定版 | 紧急撤回问题菜品 |

---

## 环境信息

| 项目 | 值 |
|------|-----|
| K8s Master | `<MASTER_IP>` |
| Argo Rollouts 版本 | v1.8.3 |
| 命名空间 | `<NAMESPACE>` |
| 已配置 Rollout | web-service, user-service |

---

## 快速上手

### 场景 1：查看当前发布状态

**需求**：我想看看 web-service 现在是什么状态

```bash
kubectl argo rollouts get rollout web-service -n <NAMESPACE>
```

**输出解读**：
```
Name:            web-service
Status:          ✔ Healthy          # ✔ 表示健康，◌ 表示进行中，॥ 表示暂停
Strategy:        Canary             # 发布策略：金丝雀
  Step:          7/7                # 当前步骤/总步骤
  SetWeight:     100                # 设定的流量比例
  ActualWeight:  100                # 实际的流量比例
Images:          xxx:v1 (stable)    # 当前运行的镜像版本

# 下面是 Pod 树状图
⟳ web-service                       # Rollout 名称
└──# revision:1                     # 版本号
   └──⧉ web-service-xxx             # ReplicaSet
      ├──□ web-service-xxx-abc      # Pod 1
      ├──□ web-service-xxx-def      # Pod 2
      └──□ web-service-xxx-ghi      # Pod 3
```

---

### 场景 2：触发新版本发布

**需求**：我要发布 web-service 的新版本 v2

**方式一：更新镜像（推荐）**
```bash
kubectl argo rollouts set image web-service \
  web=<HARBOR_URL>/<PROJECT>/web-service:v2 \
  -n <NAMESPACE>
```

**方式二：通过 patch 触发**
```bash
kubectl patch rollout web-service -n <NAMESPACE> \
  --type=merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"release":"v2"}}}}}'
```

**触发后会发生什么？**
```
1. 创建新的 ReplicaSet（canary）
2. 启动 1 个新版本 Pod
3. 10% 流量导向新版本
4. 暂停 2 分钟等待观察
5. 如果没问题，继续下一步...
```

---

### 场景 3：观察发布进度

**需求**：我想实时看发布进度

```bash
# 实时监控（按 Ctrl+C 退出）
kubectl argo rollouts get rollout web-service -n <NAMESPACE> --watch
```

**发布阶段说明**：
```
┌─────────────────────────────────────────────────────────────┐
│  10% 流量  →  暂停2min  →  30% 流量  →  暂停2min           │
│      ↓                         ↓                            │
│  50% 流量  →  暂停2min  →  100% 流量  →  完成！            │
└─────────────────────────────────────────────────────────────┘
```

---

### 场景 4：手动推进发布

**需求**：我不想等 2 分钟，想直接推进到下一步

```bash
# 推进一步
kubectl argo rollouts promote web-service -n <NAMESPACE>

# 直接全量发布（跳过所有暂停）
kubectl argo rollouts promote web-service -n <NAMESPACE> --full
```

**什么时候用？**
- `promote`：测试环境快速验证
- `promote --full`：紧急发布，确认没问题后快速上线

---

### 场景 5：发现问题，紧急回滚

**需求**：新版本有 bug，需要立刻回滚！

```bash
# 中止发布，自动回滚到稳定版
kubectl argo rollouts abort web-service -n <NAMESPACE>
```

**回滚后会发生什么？**
```
1. 新版本 Pod 被终止
2. 流量 100% 回到稳定版
3. 服务恢复正常
4. 状态变为 Degraded（降级）
```

**如果想重新发布？**
```bash
# 先重置状态
kubectl argo rollouts retry rollout web-service -n <NAMESPACE>
```

---

### 场景 6：回滚到上一个版本

**需求**：当前版本有问题，想回到上一个版本

```bash
kubectl argo rollouts undo web-service -n <NAMESPACE>
```

---

### 场景 7：查看发布历史

**需求**：我想看看之前发布过哪些版本

```bash
kubectl argo rollouts history web-service -n <NAMESPACE>
```

**输出示例**：
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>
```

---

## 完整发布流程

### 标准发布流程图

```
┌──────────────────────────────────────────────────────────────────────┐
│                        金丝雀发布完整流程                              │
│                                                                      │
│  1. 触发发布                                                          │
│     kubectl argo rollouts set image web-service web=xxx:v2           │
│                              │                                        │
│                              ▼                                        │
│  2. 金丝雀阶段（10% 流量）                                             │
│     ┌─────────────────────────────────────────┐                      │
│     │  新版本 Pod 启动                          │                      │
│     │  10% 用户访问新版本                       │                      │
│     │  90% 用户访问旧版本                       │                      │
│     │  暂停 2 分钟观察                          │                      │
│     └─────────────────────────────────────────┘                      │
│                              │                                        │
│              ┌───────────────┼───────────────┐                        │
│              ▼               ▼               ▼                        │
│         [有问题]        [没问题]        [手动推进]                     │
│              │               │               │                        │
│              ▼               ▼               ▼                        │
│         abort 回滚      等待自动推进      promote                     │
│                              │               │                        │
│                              └───────┬───────┘                        │
│                                      ▼                                │
│  3. 扩大范围（30% → 50% → 100%）                                       │
│     重复上述观察过程                                                   │
│                              │                                        │
│                              ▼                                        │
│  4. 发布完成                                                          │
│     ┌─────────────────────────────────────────┐                      │
│     │  新版本成为 stable                        │                      │
│     │  旧版本 Pod 被清理                        │                      │
│     │  100% 用户访问新版本                      │                      │
│     └─────────────────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 发布检查清单

**发布前**：
- [ ] 新镜像已推送到镜像仓库
- [ ] 在测试环境验证过新版本
- [ ] 确认回滚方案

**发布中**：
- [ ] 观察 10% 阶段的错误率
- [ ] 检查日志是否有异常
- [ ] 监控响应时间

**发布后**：
- [ ] 确认所有 Pod 都是新版本
- [ ] 验证核心功能正常
- [ ] 通知相关人员

---

## 常用命令速查表

### 基础操作

| 操作 | 命令 |
|------|------|
| 查看状态 | `kubectl argo rollouts get rollout <name> -n <ns>` |
| 实时监控 | `kubectl argo rollouts get rollout <name> -n <ns> --watch` |
| 查看历史 | `kubectl argo rollouts history <name> -n <ns>` |
| 列出所有 Rollout | `kubectl get rollouts -n <ns>` |

### 发布控制

| 操作 | 命令 |
|------|------|
| 更新镜像 | `kubectl argo rollouts set image <name> <container>=<image> -n <ns>` |
| 推进一步 | `kubectl argo rollouts promote <name> -n <ns>` |
| 全量发布 | `kubectl argo rollouts promote <name> -n <ns> --full` |
| 中止回滚 | `kubectl argo rollouts abort <name> -n <ns>` |
| 回滚上一版 | `kubectl argo rollouts undo <name> -n <ns>` |
| 重试发布 | `kubectl argo rollouts retry rollout <name> -n <ns>` |
| 重启 Pod | `kubectl argo rollouts restart <name> -n <ns>` |

---

## 常见问题 FAQ

### Q1: Rollout 和 Deployment 有什么区别？

**A**: Rollout 是 Deployment 的"增强版"：

| 特性 | Deployment | Rollout |
|------|------------|---------|
| 滚动更新 | ✅ | ✅ |
| 金丝雀发布 | ❌ | ✅ |
| 蓝绿部署 | ❌ | ✅ |
| 流量控制 | ❌ | ✅ |
| 自动回滚 | ❌ | ✅ |
| 发布暂停 | ❌ | ✅ |

### Q2: 发布卡在 Paused 状态怎么办？

**A**: 这是正常的！金丝雀发布会在每个阶段暂停等待观察。

```bash
# 方式1：等待自动推进（默认 2 分钟）
# 方式2：手动推进
kubectl argo rollouts promote web-service -n <NAMESPACE>
```

### Q3: 发布失败，状态是 Degraded 怎么办？

**A**: Degraded 表示发布被中止或失败。

```bash
# 1. 查看详细状态
kubectl argo rollouts get rollout web-service -n <NAMESPACE>

# 2. 如果要重新发布
kubectl argo rollouts retry rollout web-service -n <NAMESPACE>

# 3. 如果要回到稳定版
kubectl argo rollouts undo web-service -n <NAMESPACE>
```

### Q4: 如何修改金丝雀发布的步骤？

**A**: 修改 Rollout 的 strategy.canary.steps：

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10      # 第1步：10% 流量
    - pause: {duration: 2m}
    - setWeight: 30      # 第2步：30% 流量
    - pause: {duration: 2m}
    - setWeight: 50      # 第3步：50% 流量
    - pause: {duration: 2m}
    - setWeight: 100     # 第4步：全量
```

### Q5: 如何实现自动回滚？

**A**: 集成 Prometheus 分析，当错误率超过阈值时自动回滚（高级功能，需要额外配置 AnalysisTemplate）。

---

## 最佳实践

### 1. 发布时间选择

```
✅ 推荐：工作日上午 10:00-11:00，下午 14:00-16:00
❌ 避免：周五下午、节假日前、深夜
```

### 2. 流量比例建议

```
低风险变更：10% → 50% → 100%
中风险变更：10% → 30% → 50% → 100%
高风险变更：5% → 10% → 30% → 50% → 100%
```

### 3. 观察时间建议

```
简单变更：每阶段 2-5 分钟
复杂变更：每阶段 10-30 分钟
核心服务：每阶段 30-60 分钟
```

### 4. 回滚决策

```
立即回滚的情况：
- 错误率明显上升
- 响应时间大幅增加
- 核心功能异常
- 用户投诉增多

继续观察的情况：
- 指标波动在正常范围
- 只有非核心功能受影响
- 问题可以快速修复
```

---

## Rollout 配置示例

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-service
  namespace: <NAMESPACE>
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: web-service
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 30
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 100
  template:
    metadata:
      labels:
        app: web-service
    spec:
      containers:
      - name: web
        image: <HARBOR_URL>/<PROJECT>/web-service:v1
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

---

## 总结

### 金丝雀发布三步曲

```
1. 触发：set image 或 patch
2. 观察：get rollout --watch
3. 决策：promote（继续）或 abort（回滚）
```

### 记住这三个命令就够了

```bash
# 发布
kubectl argo rollouts set image <name> <container>=<image> -n <ns>

# 推进
kubectl argo rollouts promote <name> -n <ns>

# 回滚
kubectl argo rollouts abort <name> -n <ns>
```

---

## 相关链接

- [Argo Rollouts 官方文档](https://argoproj.github.io/argo-rollouts/)
- [Argo Rollouts GitHub](https://github.com/argoproj/argo-rollouts)
- [金丝雀发布 vs 蓝绿部署](https://argoproj.github.io/argo-rollouts/concepts/)

---

> 📝 本文基于 Argo Rollouts v1.8.3 编写，如有问题欢迎留言讨论！
