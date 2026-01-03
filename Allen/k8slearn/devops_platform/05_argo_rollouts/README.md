# Argo Rollouts 部署指南

> 🎯 为 service-test 微服务实现金丝雀发布和蓝绿部署能力

## 当前状态

**更新时间**: 2026-01-02

| 项目 | 状态 | 说明 |
|------|------|------|
| Argo Rollouts Controller | ✅ 已安装 | v1.8.3 |
| kubectl 插件 | ✅ 已安装 | /usr/local/bin/kubectl-argo-rollouts |
| 命名空间 | ✅ 已创建 | argo-rollouts |
| Rollout 配置 | ✅ 已部署 | web-service ✅, user-service ✅ |

---

## 快速开始

### 1. 安装 Argo Rollouts（已完成 ✅）

由于服务器无法直接访问 GitHub，采用本地下载后上传的方式：

```bash
# 步骤 1：本地下载（需要代理）
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 步骤 2：上传到服务器
scp install.yaml root@182.42.82.135:/tmp/argo-rollouts-install.yaml

# 步骤 3：创建命名空间并安装
ssh root@182.42.82.135 'kubectl create namespace argo-rollouts'
ssh root@182.42.82.135 'kubectl apply -n argo-rollouts -f /tmp/argo-rollouts-install.yaml'
```

### 2. 安装 kubectl 插件（已完成 ✅）

```bash
# 本地下载
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

# 上传并安装
scp kubectl-argo-rollouts-linux-amd64 root@182.42.82.135:/tmp/
ssh root@182.42.82.135 'chmod +x /tmp/kubectl-argo-rollouts-linux-amd64 && mv /tmp/kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts'
```

### 3. 验证安装

```bash
# 查看 Pod 状态
ssh root@182.42.82.135 'kubectl get pods -n argo-rollouts'
# 输出: argo-rollouts-64d959676c-kcjjp   1/1     Running

# 查看版本
ssh root@182.42.82.135 'kubectl argo rollouts version'
```

### 4. 部署 Rollout（下一步）

```bash
# 先删除现有的 Deployment
ssh root@182.42.82.135 'kubectl delete deployment web-service -n service-test'
ssh root@182.42.82.135 'kubectl delete deployment user-service -n service-test'

# 应用 Rollout 配置
ssh root@182.42.82.135 'kubectl apply -f /path/to/web-service-rollout.yaml'
ssh root@182.42.82.135 'kubectl apply -f /path/to/user-service-rollout.yaml'
```

---

## 目录结构

```
05_argo_rollouts/
├── README.md                           # 本文档
├── DESIGN.md                           # 设计方案
├── ARGO_ROLLOUTS_TUTORIAL.md           # 深入浅出教程 ⭐
│
├── install/
│   ├── 01-namespace.yaml               # namespace
│   ├── 02-install.sh                   # 安装脚本
│   ├── 03-dashboard-service.yaml       # Dashboard NodePort
│   └── install.yaml                    # Argo Rollouts 官方安装文件 (v1.8.3)
│
├── rollouts/
│   ├── web-service-rollout.yaml        # web-service 金丝雀配置
│   └── user-service-rollout.yaml       # user-service 金丝雀配置
│
└── examples/
    ├── canary-basic.yaml               # 基础金丝雀示例
    └── bluegreen-basic.yaml            # 蓝绿部署示例
```

---

## 服务发布策略

| 服务 | 发布策略 | 说明 |
|------|----------|------|
| **web-service** | 金丝雀 | 面向用户，逐步验证 |
| **user-service** | 金丝雀 | 核心服务，谨慎发布 |
| **product-service** | 滚动更新 | 保持 Deployment |
| **trade-service** | 滚动更新 | 保持 Deployment |

---

## 金丝雀发布步骤

```
10% 流量 → 暂停 2min → 30% 流量 → 暂停 2min → 50% 流量 → 暂停 2min → 100% 流量
```

---

## 常用命令

```bash
# === 查看状态 ===
ssh root@182.42.82.135 'kubectl argo rollouts get rollout web-service -n service-test'
ssh root@182.42.82.135 'kubectl argo rollouts get rollout web-service -n service-test --watch'

# === 触发发布 ===
ssh root@182.42.82.135 'kubectl argo rollouts set image web-service \
  web=182.42.82.135:30002/service-test/web-service:v2 \
  -n service-test'

# === 控制发布 ===
ssh root@182.42.82.135 'kubectl argo rollouts promote web-service -n service-test'   # 推进
ssh root@182.42.82.135 'kubectl argo rollouts abort web-service -n service-test'     # 中止
ssh root@182.42.82.135 'kubectl argo rollouts undo web-service -n service-test'      # 回滚

# === 查看历史 ===
ssh root@182.42.82.135 'kubectl argo rollouts history web-service -n service-test'
```

---

## 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| Rollouts Dashboard | http://182.42.82.135:30100 | 可视化管理（需安装 Dashboard） |

---

## 相关文档

- [USER_GUIDE.md](./USER_GUIDE.md) - 用户操作指南 ⭐ 新手必读
- [DESIGN.md](./DESIGN.md) - 详细设计方案
- [ARGO_ROLLOUTS_TUTORIAL.md](./ARGO_ROLLOUTS_TUTORIAL.md) - 深入浅出教程
- [Argo Rollouts 官方文档](https://argoproj.github.io/argo-rollouts/)

---

## 进度

1. ✅ 安装 Argo Rollouts (v1.8.3)
2. ✅ 安装 kubectl 插件
3. ✅ 创建 Rollout 配置文件
4. ✅ 迁移 web-service 到 Rollout
5. ✅ 迁移 user-service 到 Rollout
6. ✅ 测试金丝雀发布
7. ⏳ 集成 Prometheus 自动分析（可选）

---

## 安装记录

**2026-01-02 安装完成**

```
# 安装的资源
customresourcedefinition.apiextensions.k8s.io/analysisruns.argoproj.io
customresourcedefinition.apiextensions.k8s.io/analysistemplates.argoproj.io
customresourcedefinition.apiextensions.k8s.io/clusteranalysistemplates.argoproj.io
customresourcedefinition.apiextensions.k8s.io/experiments.argoproj.io
customresourcedefinition.apiextensions.k8s.io/rollouts.argoproj.io
serviceaccount/argo-rollouts
clusterrole.rbac.authorization.k8s.io/argo-rollouts
clusterrolebinding.rbac.authorization.k8s.io/argo-rollouts
configmap/argo-rollouts-config
secret/argo-rollouts-notification-secret
service/argo-rollouts-metrics
deployment.apps/argo-rollouts

# Pod 状态
argo-rollouts-64d959676c-kcjjp   1/1     Running   (argo-rollouts namespace)

# 镜像版本
quay.io/argoproj/argo-rollouts:v1.8.3
```

---

## 金丝雀发布测试记录

**2026-01-02 测试完成**

### 测试流程

```bash
# 1. 触发金丝雀发布（通过修改 annotation）
kubectl patch rollout web-service -n service-test --type=merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"rollout-trigger":"timestamp"}}}}}'

# 2. 查看发布状态
kubectl argo rollouts get rollout web-service -n service-test

# 3. 手动推进（跳过等待时间）
kubectl argo rollouts promote web-service -n service-test

# 4. 全量发布
kubectl argo rollouts promote web-service -n service-test --full
```

### 发布步骤演示

```
Step 0/7: SetWeight 10%  → Paused 2min
Step 1/7: 暂停观察
Step 2/7: SetWeight 30%  → Paused 2min  
Step 3/7: 暂停观察
Step 4/7: SetWeight 50%  → Paused 2min
Step 5/7: 暂停观察
Step 6/7: SetWeight 100%
Step 7/7: 完成，新版本成为 stable
```

### 关键命令

| 命令 | 说明 |
|------|------|
| `kubectl argo rollouts get rollout <name> -n <ns>` | 查看发布状态 |
| `kubectl argo rollouts promote <name> -n <ns>` | 推进到下一步 |
| `kubectl argo rollouts promote <name> -n <ns> --full` | 直接全量发布 |
| `kubectl argo rollouts abort <name> -n <ns>` | 中止发布，回滚 |
| `kubectl argo rollouts undo <name> -n <ns>` | 回滚到上一版本 |
