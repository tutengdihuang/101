# Argo Rollouts 部署指南

> 🎯 为 service-test 微服务实现金丝雀发布和蓝绿部署能力

## 快速开始

### 1. 安装 Argo Rollouts

```bash
# 在服务器上执行
cd /path/to/05_argo_rollouts/install
chmod +x 02-install.sh
./02-install.sh

# 或者手动执行
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### 2. 安装 kubectl 插件（推荐）

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### 3. 验证安装

```bash
kubectl get pods -n argo-rollouts
kubectl argo rollouts version
```

### 4. 部署 Rollout

```bash
# 先删除现有的 Deployment
kubectl delete deployment web-service -n service-test
kubectl delete deployment user-service -n service-test

# 应用 Rollout 配置
kubectl apply -f rollouts/web-service-rollout.yaml
kubectl apply -f rollouts/user-service-rollout.yaml
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
│   └── 03-dashboard-service.yaml       # Dashboard NodePort
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
kubectl argo rollouts get rollout web-service -n service-test
kubectl argo rollouts get rollout web-service -n service-test --watch

# === 触发发布 ===
kubectl argo rollouts set image web-service \
  web=182.42.82.135:30002/service-test/web-service:v2 \
  -n service-test

# === 控制发布 ===
kubectl argo rollouts promote web-service -n service-test      # 推进
kubectl argo rollouts abort web-service -n service-test        # 中止
kubectl argo rollouts undo web-service -n service-test         # 回滚

# === 查看历史 ===
kubectl argo rollouts history web-service -n service-test
```

---

## 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| Rollouts Dashboard | http://182.42.82.135:30100 | 可视化管理（需安装 Dashboard） |

---

## 相关文档

- [DESIGN.md](./DESIGN.md) - 详细设计方案
- [ARGO_ROLLOUTS_TUTORIAL.md](./ARGO_ROLLOUTS_TUTORIAL.md) - 深入浅出教程
- [Argo Rollouts 官方文档](https://argoproj.github.io/argo-rollouts/)

---

## 下一步

1. ✅ 安装 Argo Rollouts
2. ✅ 创建 Rollout 配置
3. ⏳ 迁移 web-service 到 Rollout
4. ⏳ 测试金丝雀发布
5. ⏳ 迁移 user-service 到 Rollout
6. ⏳ 集成 Prometheus 自动分析（可选）
