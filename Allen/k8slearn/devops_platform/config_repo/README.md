# GitOps 配置仓库

这是 ArgoCD 监听的配置仓库，存放所有 K8s 部署配置。

## 为什么需要独立配置仓库？

| 方式 | 说明 | 推荐 |
|------|------|------|
| 代码和配置同仓库 | 简单，但职责不清 | ❌ |
| **独立配置仓库** | 职责分离，权限独立 | ✅ |

## 仓库结构

```
service-test-config/
├── README.md
├── base/                         # 基础配置
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── user/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── product/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── trade/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── web/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/                      # 开发环境
│   │   ├── kustomization.yaml
│   │   └── patches/
│   │       └── replicas.yaml
│   ├── staging/                  # 测试环境
│   │   ├── kustomization.yaml
│   │   └── patches/
│   │       └── replicas.yaml
│   └── prod/                     # 生产环境
│       ├── kustomization.yaml
│       └── patches/
│           ├── replicas.yaml
│           └── resources.yaml
└── argocd/
    └── application.yaml          # ArgoCD Application 定义
```

## Kustomize 示例

### base/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- configmap.yaml
- user/deployment.yaml
- user/service.yaml
- product/deployment.yaml
- product/service.yaml
- trade/deployment.yaml
- trade/service.yaml
- web/deployment.yaml
- web/service.yaml
```

### overlays/prod/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patches:
- path: patches/replicas.yaml
- path: patches/resources.yaml

images:
- name: harbor.example.com/service-test/user-service
  newTag: v1.2.3
- name: harbor.example.com/service-test/product-service
  newTag: v1.2.3
- name: harbor.example.com/service-test/trade-service
  newTag: v1.2.3
- name: harbor.example.com/service-test/web-service
  newTag: v1.2.3
```

## CI 更新镜像 Tag

Tekton Pipeline 构建完成后，更新配置仓库：

```bash
# 克隆配置仓库
git clone https://gitee.com/username/service-test-config.git
cd service-test-config

# 更新镜像 tag
cd overlays/prod
kustomize edit set image harbor.example.com/service-test/user-service:v1.2.4

# 提交
git add .
git commit -m "chore: update user-service to v1.2.4"
git push
```

ArgoCD 检测到变更后自动部署。

## 多环境部署

```
┌─────────────────────────────────────────────────────────────┐
│                    ArgoCD Applications                       │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ service-dev │  │service-stag │  │service-prod │         │
│  │ overlays/dev│  │overlays/stag│  │overlays/prod│         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│    Dev 集群         Staging 集群      Prod 集群            │
└─────────────────────────────────────────────────────────────┘
```

## 下一步

1. 创建 Gitee 配置仓库
2. 初始化目录结构
3. 配置 ArgoCD Application
4. 集成 Tekton 自动更新
