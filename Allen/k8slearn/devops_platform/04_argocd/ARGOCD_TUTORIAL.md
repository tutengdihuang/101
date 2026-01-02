# ArgoCD 深入浅出教程

> 🎯 **一句话定位**：ArgoCD 是 K8s 原生的 GitOps CD 工具，让 Git 仓库成为部署的"唯一真相来源"。

## 秒懂 ArgoCD（30秒版）

**解决什么问题**：
```
传统部署：手动 kubectl apply，容易出错，难以追踪谁改了什么
ArgoCD：Git 仓库里的配置 = 集群里的状态，自动同步，有迹可循
```

**一句话精华**：
```
ArgoCD = Git 仓库是老板，K8s 集群是员工，员工必须按老板说的做
```

**适合谁学**：已经会 K8s 基础，想实现 GitOps 的开发者
**不适合谁**：完全不懂 K8s 和 Git 的新手

---

## 核心概念（用生活比喻理解）

### GitOps 是什么？

**传统部署 vs GitOps**：

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        传统部署 vs GitOps                                │
│                                                                         │
│  【传统部署】                                                            │
│  开发者 → 手动 kubectl apply → K8s 集群                                 │
│                                                                         │
│  问题：                                                                  │
│  - 谁改了什么？不知道                                                    │
│  - 改错了怎么回滚？手动改回去                                            │
│  - 多人操作会冲突                                                        │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  【GitOps】                                                              │
│  开发者 → Git Push → Git 仓库 ← ArgoCD 监听 → K8s 集群                  │
│                                                                         │
│  优点：                                                                  │
│  - 所有变更都有 Git 记录                                                 │
│  - 回滚 = Git revert                                                    │
│  - Git 仓库是唯一真相来源                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

**生活比喻**：

```
传统部署 = 口头传达命令
  老板说："把桌子搬到那边"
  员工搬了，但没人记录
  下次问"桌子原来在哪？"，没人知道

GitOps = 书面命令
  老板写在纸上："桌子放在 A 位置"
  员工按纸上说的做
  所有命令都有记录，随时可以查
```

### ArgoCD 核心概念

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| **Application** | 一个要部署的应用 | 一份工作任务书 |
| **Source** | 配置文件在哪里（Git 仓库） | 任务书的来源 |
| **Destination** | 部署到哪里（K8s 集群） | 任务执行的地点 |
| **Sync** | 同步操作 | 按任务书执行 |
| **Health** | 应用健康状态 | 任务完成情况 |

---

## 从你的项目理解 ArgoCD

### Application —— 核心资源

看你项目中的 `service-test-app.yaml`：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: service-test              # 应用名称
  namespace: argocd               # ArgoCD 所在的 namespace
spec:
  project: default                # 项目（权限管理用）
  
  # 📦 Source：配置文件在哪里
  source:
    repoURL: https://gitee.com/bitcash/service_test.git  # Git 仓库地址
    targetRevision: main          # 分支/tag/commit
    path: k8s                     # 配置文件所在目录
    directory:
      recurse: true               # 递归扫描子目录
  
  # 🎯 Destination：部署到哪里
  destination:
    server: https://kubernetes.default.svc  # K8s API Server
    namespace: service-test       # 目标 namespace
  
  # 🔄 SyncPolicy：同步策略
  syncPolicy:
    automated:                    # 自动同步
      prune: true                 # 删除 Git 中没有的资源
      selfHeal: true              # 自动修复漂移
    syncOptions:
    - CreateNamespace=true        # 自动创建 namespace
```

### 逐行解读

#### 1. Source（来源）—— 配置文件在哪里

```yaml
source:
  repoURL: https://gitee.com/bitcash/service_test.git  # Git 仓库
  targetRevision: main          # 分支
  path: k8s                     # 目录
  directory:
    recurse: true               # 递归扫描
```

**对应的 Git 仓库结构**：
```
service_test/
├── k8s/                        ← ArgoCD 监听这个目录
│   ├── configmaps.yaml
│   ├── namespace.yaml
│   ├── user/
│   │   └── deployment.yaml     ← recurse: true 才能扫描到
│   ├── product/
│   │   └── deployment.yaml
│   ├── trade/
│   │   └── deployment.yaml
│   └── web/
│       └── deployment.yaml
└── ...
```

**常见误区** 🚫：
```
❌ 误区：ArgoCD 默认会扫描子目录
✅ 正确：需要设置 directory.recurse: true 才会递归扫描

你的项目就遇到过这个问题！
没设置 recurse: true 时，ArgoCD 只看到 configmaps.yaml 和 namespace.yaml
设置后，才能看到 user/、product/ 等子目录下的 deployment.yaml
```

#### 2. Destination（目标）—— 部署到哪里

```yaml
destination:
  server: https://kubernetes.default.svc  # K8s API Server
  namespace: service-test                  # 目标 namespace
```

**解释**：
- `server`：K8s 集群的 API Server 地址
  - `https://kubernetes.default.svc` 表示 ArgoCD 所在的集群
  - 也可以配置其他集群（多集群部署）
- `namespace`：资源部署到哪个 namespace

#### 3. SyncPolicy（同步策略）—— 怎么同步

```yaml
syncPolicy:
  automated:          # 自动同步
    prune: true       # 删除多余资源
    selfHeal: true    # 自动修复
```

**三种同步模式**：

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| **手动同步** | 不设置 automated | 生产环境，需要人工确认 |
| **自动同步** | automated: {} | 开发/测试环境 |
| **自动同步+修复** | automated + selfHeal | 希望集群状态始终与 Git 一致 |

**prune 和 selfHeal 的区别**：

```
prune: true
  Git 仓库删除了 deployment-old.yaml
  → ArgoCD 会自动删除集群中的 deployment-old

selfHeal: true
  有人手动 kubectl edit 修改了 deployment
  → ArgoCD 会自动改回 Git 仓库中的配置
```

**生活比喻**：
```
prune = 清理多余的东西
  任务书上没有的桌子，要搬走

selfHeal = 纠正错误
  有人把桌子搬错位置了，自动搬回正确位置
```

---

## ArgoCD 工作原理

### 同步流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ArgoCD 同步流程                                   │
│                                                                         │
│  1. ArgoCD 定期轮询 Git 仓库（默认 3 分钟）                               │
│         │                                                               │
│         ▼                                                               │
│  2. 比较 Git 仓库配置 vs K8s 集群状态                                    │
│         │                                                               │
│         ├── 一致 → Synced（已同步）                                      │
│         │                                                               │
│         └── 不一致 → OutOfSync（未同步）                                 │
│                 │                                                       │
│                 ▼                                                       │
│  3. 如果配置了自动同步                                                   │
│         │                                                               │
│         ▼                                                               │
│  4. 执行 kubectl apply（同步资源）                                       │
│         │                                                               │
│         ▼                                                               │
│  5. 检查资源健康状态                                                     │
│         │                                                               │
│         ├── Healthy（健康）                                              │
│         ├── Progressing（进行中）                                        │
│         ├── Degraded（降级）                                             │
│         └── Missing（缺失）                                              │
└─────────────────────────────────────────────────────────────────────────┘
```

### 状态说明

**同步状态（Sync Status）**：

| 状态 | 说明 | 图标 |
|------|------|------|
| **Synced** | Git 和集群一致 | ✅ |
| **OutOfSync** | Git 和集群不一致 | ⚠️ |
| **Unknown** | 无法确定状态 | ❓ |

**健康状态（Health Status）**：

| 状态 | 说明 | 图标 |
|------|------|------|
| **Healthy** | 所有资源正常运行 | 💚 |
| **Progressing** | 资源正在部署中 | 🔄 |
| **Degraded** | 资源有问题 | 🔴 |
| **Suspended** | 资源被暂停 | ⏸️ |
| **Missing** | 资源不存在 | ❌ |

---

## 实际操作指南

### 1. 查看应用状态

```bash
# 查看所有 Application
kubectl get applications -n argocd

# 输出示例：
# NAME           SYNC STATUS   HEALTH STATUS
# service-test   Synced        Healthy

# 查看详细状态
kubectl describe application service-test -n argocd
```

### 2. 手动触发同步

```bash
# 方式1：kubectl 命令
kubectl annotate application service-test -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# 方式2：ArgoCD UI
# 访问 http://182.42.82.135:30090 → 点击 Sync 按钮
```

### 3. 查看同步历史

```bash
# 查看 Application 的同步历史
kubectl get application service-test -n argocd -o yaml | grep -A 20 history
```

### 4. 回滚部署

```bash
# 方式1：Git revert（推荐）
cd /Volumes/mac_data/code/go_code/service_test
git revert HEAD
git push
# ArgoCD 会自动同步回滚后的配置

# 方式2：K8s rollout（临时）
kubectl rollout undo deployment/user-service -n service-test
# 注意：如果开启了 selfHeal，ArgoCD 会自动改回 Git 配置
```

---

## 与 Tekton 的配合

### CI/CD 完整流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CI/CD 完整流程                                    │
│                                                                         │
│  【CI 部分 - Tekton】                                                    │
│                                                                         │
│  1. 开发者推送代码到 Gitee                                               │
│         │                                                               │
│         ▼                                                               │
│  2. Gitee Webhook 触发 Tekton                                           │
│         │                                                               │
│         ▼                                                               │
│  3. Tekton Pipeline 执行                                                │
│         │  - git clone                                                  │
│         │  - docker build                                               │
│         │  - docker push to Harbor                                      │
│         ▼                                                               │
│  4. 镜像推送到 Harbor                                                    │
│         - service-test/user-service:v1                                  │
│         - service-test/product-service:v1                               │
│         - ...                                                           │
│                                                                         │
│  ═══════════════════════════════════════════════════════════════════════│
│                                                                         │
│  【CD 部分 - ArgoCD】                                                    │
│                                                                         │
│  5. ArgoCD 监听 Gitee k8s 目录                                          │
│         │  （每 3 分钟轮询一次）                                         │
│         ▼                                                               │
│  6. 检测到 k8s 配置变化                                                  │
│         │  （如 deployment.yaml 中的镜像 tag 变了）                      │
│         ▼                                                               │
│  7. 自动同步到 K8s 集群                                                  │
│         │  kubectl apply -f ...                                         │
│         ▼                                                               │
│  8. 服务部署完成                                                         │
│         - user-service Pod 更新                                         │
│         - product-service Pod 更新                                      │
│         - ...                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### CI 和 CD 的分工

| 阶段 | 工具 | 职责 |
|------|------|------|
| **CI** | Tekton | 构建镜像、推送到 Harbor |
| **CD** | ArgoCD | 监听 Git、同步到 K8s |

**关键点**：
```
Tekton 负责：代码 → 镜像
ArgoCD 负责：配置 → 部署

它们通过 Git 仓库连接：
- Tekton 构建完镜像后，可以更新 Git 仓库中的镜像 tag
- ArgoCD 检测到 Git 变化，自动部署新镜像
```

---

## 常见问题 FAQ

### Q1: ArgoCD 多久同步一次？

```
默认：每 3 分钟轮询一次 Git 仓库

如何加快？
1. 手动触发同步
2. 配置 Webhook（Git 推送时主动通知 ArgoCD）
3. 修改轮询间隔（不推荐太短，会增加 Git 服务器压力）
```

### Q2: 为什么 ArgoCD 显示 Synced 但 Pod 没更新？

```
可能原因：
1. 镜像 tag 没变（如一直用 :latest）
   解决：使用具体的 tag（如 :v1, :v2）

2. imagePullPolicy 是 IfNotPresent
   解决：改为 Always，或使用不同的 tag

3. Deployment 配置没变
   解决：确保 deployment.yaml 中的镜像 tag 已更新
```

### Q3: 如何让 ArgoCD 只同步特定文件？

```yaml
source:
  path: k8s
  directory:
    recurse: true
    exclude: '*.md'    # 排除 markdown 文件
    include: '*.yaml'  # 只包含 yaml 文件
```

### Q4: selfHeal 会不会覆盖我的手动修改？

```
会！这就是 selfHeal 的作用。

如果你需要临时修改：
1. 关闭 selfHeal
2. 手动修改
3. 测试完成后，把修改提交到 Git
4. 重新开启 selfHeal

最佳实践：
所有修改都通过 Git 提交，不要手动 kubectl edit
```

### Q5: 如何处理敏感信息（Secret）？

```
问题：Secret 不能明文存在 Git 仓库

解决方案：
1. Sealed Secrets - 加密后存储
2. External Secrets - 从外部密钥管理系统获取
3. Vault - HashiCorp Vault 集成
4. SOPS - 加密 YAML 文件

你的项目中，Harbor 密码等敏感信息应该用这些方式管理
```

---

## 你的项目遇到的问题

### 问题1: ArgoCD 同步成功但没有创建资源

**现象**：
```
kubectl get applications -n argocd 显示 Synced
kubectl get pods -n service-test 显示 No resources found
```

**原因**：没有设置 `directory.recurse: true`

**解决**：
```yaml
source:
  path: k8s
  directory:
    recurse: true  # 添加这行
```

### 问题2: Pod ImagePullBackOff

**现象**：
```
kubectl get pods -n service-test
NAME                    READY   STATUS             RESTARTS   AGE
user-service-xxx        0/1     ImagePullBackOff   0          10h
```

**原因**：deployment.yaml 中的镜像 tag 与 Harbor 中的不一致

**解决**：
```yaml
# 确保 deployment.yaml 中的镜像 tag 与 Harbor 一致
image: 182.42.82.135:30002/service-test/user-service:v1  # 不是 :6
```

### 问题3: web-service CrashLoopBackOff

**现象**：
```
kubectl logs web-service-xxx -n service-test
[HTTP] 404 - GET /health - kube-probe/1.28
```

**原因**：web-service 没有 `/health` 端点，但配置了 HTTP 健康检查

**解决**：
```yaml
# 改用 TCP 探针
livenessProbe:
  tcpSocket:
    port: 8888
  # 而不是
  # httpGet:
  #   path: /health
  #   port: 8888
```

---

## 金句总结

```
📌 ArgoCD 的本质：Git 仓库是唯一真相来源

📌 核心概念记忆：
   Application = 一份工作任务书
   Source = 任务书的来源（Git 仓库）
   Destination = 任务执行的地点（K8s 集群）
   Sync = 按任务书执行

📌 同步策略：
   prune = 清理多余的东西
   selfHeal = 纠正错误

📌 与 Tekton 的分工：
   Tekton = CI（代码 → 镜像）
   ArgoCD = CD（配置 → 部署）

📌 一句话带走：
   "ArgoCD 让 Git 成为部署的老板，集群必须按 Git 说的做"
```

---

## 延伸学习

**想深入学习**：
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitOps 原则](https://www.gitops.tech/)

**下一步**：
- 学习 Argo Rollouts，实现金丝雀/蓝绿发布
- 学习 Sealed Secrets，安全管理敏感信息
- 学习多集群部署

---

## 附录：常用命令速查

```bash
# === ArgoCD 应用管理 ===
# 查看所有应用
kubectl get applications -n argocd

# 查看应用详情
kubectl describe application service-test -n argocd

# 手动触发同步
kubectl annotate application service-test -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# === ArgoCD 组件状态 ===
# 查看 ArgoCD Pod
kubectl get pods -n argocd

# 查看 ArgoCD 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50

# === 服务状态 ===
# 查看部署的服务
kubectl get pods -n service-test

# 查看服务日志
kubectl logs -n service-test -l app=user-service --tail=30

# === 访问地址 ===
# ArgoCD UI: http://182.42.82.135:30090
# 用户名: admin
# 密码: admin123
```

---

*文档版本：v1.0 | 更新日期：2026-01-02 | 基于项目：service-test CI/CD*
