# Argo Rollouts 部署指南

Argo Rollouts 提供 Kubernetes 的高级部署策略：金丝雀发布、蓝绿部署。

## 核心概念

### 金丝雀发布

```
v1 (100%) ──▶ v2 (10%) ──▶ v2 (50%) ──▶ v2 (100%)
              │
              └── 观察指标，逐步切流量
```

### 蓝绿部署

```
蓝 (v1) ◀── 当前流量
绿 (v2) ◀── 新版本就绪
    │
    └── 一键切换流量
```

## 部署步骤

### 1. 安装 Argo Rollouts

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### 2. 安装 kubectl 插件（可选）

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### 3. 验证安装

```bash
kubectl get pods -n argo-rollouts
```

## 金丝雀发布示例

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: user-service
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 10        # 10% 流量到新版本
      - pause: {duration: 5m} # 观察 5 分钟
      - setWeight: 30
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 5m}
      - setWeight: 100       # 全量发布
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user
        image: harbor/user-service:v2
```

## 蓝绿部署示例

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-service
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: web-service-active
      previewService: web-service-preview
      autoPromotionEnabled: false  # 手动确认切换
  selector:
    matchLabels:
      app: web-service
  template:
    # ...
```

## 常用命令

```bash
# 查看 Rollout 状态
kubectl argo rollouts get rollout user-service

# 手动推进金丝雀
kubectl argo rollouts promote user-service

# 回滚
kubectl argo rollouts undo user-service

# 中止发布
kubectl argo rollouts abort user-service
```

## 目录结构

```
05_argo_rollouts/
├── README.md
├── install/
│   └── argo-rollouts-install.yaml
└── examples/
    ├── canary-rollout.yaml       # 金丝雀示例
    └── bluegreen-rollout.yaml    # 蓝绿示例
```

## 与 ArgoCD 集成

ArgoCD 原生支持 Argo Rollouts，只需将 Deployment 替换为 Rollout 即可。

## 下一步

1. 安装 Argo Rollouts
2. 将 Deployment 改为 Rollout
3. 配置发布策略
4. 测试金丝雀发布
