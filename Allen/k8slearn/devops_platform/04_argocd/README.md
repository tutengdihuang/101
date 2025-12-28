# ArgoCD 部署指南

ArgoCD 是 Kubernetes 原生的 GitOps 持续部署工具。

## 部署状态

**状态**: ✅ 已部署

| 项目 | 值 |
|------|-----|
| **命名空间** | argocd |
| **访问地址** | `http://<MASTER_IP>:30090` |
| **用户名** | admin |
| **密码** | admin123 |
| **镜像版本** | quay.io/argoproj/argocd:v2.9.3 |

## 核心概念

```
Git 配置仓库 ◀──监听──▶ ArgoCD ──同步──▶ K8s 集群
```

**GitOps 原则**：
- Git 是唯一真实来源
- 所有变更通过 Git 提交
- 自动检测配置漂移
- 回滚 = git revert

## 已部署组件

```bash
$ kubectl get pods -n argocd
NAME                                             READY   STATUS
argocd-application-controller-xxx                1/1     Running
argocd-redis-xxx                                 1/1     Running
argocd-repo-server-xxx                           1/1     Running
argocd-server-xxx                                1/1     Running
```

## 安装文件

```
04_argocd/
├── README.md
└── install/
    ├── argocd-crds.yaml              # CRD 定义
    ├── argocd-install.yaml           # RBAC 和基础配置
    ├── argocd-components.yaml        # 核心组件 (使用 quay.io 镜像)
    └── argocd-default-project.yaml   # 默认项目
```

## 部署步骤（已完成）

```bash
# 1. 创建 CRDs
kubectl apply -f argocd-crds.yaml

# 2. 创建 RBAC 和基础配置
kubectl apply -f argocd-install.yaml

# 3. 部署核心组件
kubectl apply -f argocd-components.yaml

# 4. 创建默认项目
kubectl apply -f argocd-default-project.yaml

# 5. 设置 admin 密码
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$10$xxx"}}'
```

## 配置应用

### 创建 Application（连接 Gitee 仓库）

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: service-test
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitee.com/bitcash/service_test.git
    targetRevision: HEAD
    path: k8s                    # K8s 配置文件目录
  destination:
    server: https://kubernetes.default.svc
    namespace: service-test
  syncPolicy:
    automated:
      prune: true                # 自动删除不在 Git 中的资源
      selfHeal: true             # 自动修复配置漂移
```

### 通过 UI 创建应用

1. 访问 `http://<MASTER_IP>:30090`
2. 登录 (admin / admin123)
3. 点击 `+ NEW APP`
4. 填写：
   - Application Name: `service-test`
   - Project: `default`
   - Repository URL: `https://gitee.com/bitcash/service_test.git`
   - Path: `k8s`
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: `service-test`
5. 点击 `CREATE`

## 目录结构

```
04_argocd/
├── README.md
├── install/
│   ├── argocd-crds.yaml              # CRD 定义
│   ├── argocd-install.yaml           # RBAC 和基础配置
│   ├── argocd-components.yaml        # 核心组件
│   └── argocd-default-project.yaml   # 默认项目
├── apps/
│   └── service-test.yaml             # 应用定义 (待创建)
└── projects/
    └── default.yaml                  # 项目定义
```

## GitOps 配置仓库结构

当前使用 Gitee 仓库中的 `k8s/` 目录作为配置源：

```
service_test/                     # Gitee 仓库
├── k8s/                          # ArgoCD 监听此目录
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── user/deployment.yaml
│   ├── product/deployment.yaml
│   ├── trade/deployment.yaml
│   └── web/deployment.yaml
└── ...
```

## 工作流程

```
1. Tekton 构建镜像，推送到 Harbor
         │
         ▼
2. Tekton 更新 Gitee 仓库中的镜像 tag
         │
         ▼
3. ArgoCD 检测到配置变更
         │
         ▼
4. ArgoCD 自动同步到 K8s 集群
```

## 常用命令

```bash
# 查看 ArgoCD 状态
kubectl get pods -n argocd

# 查看应用列表
kubectl get applications -n argocd

# 查看应用详情
kubectl describe application service-test -n argocd

# 手动同步应用
kubectl -n argocd patch application service-test --type merge -p '{"operation": {"sync": {}}}'
```

## 下一步

1. ✅ 安装 ArgoCD
2. 在 Gitee 仓库中准备 K8s 配置文件
3. 创建 ArgoCD Application
4. 集成 Tekton（自动更新镜像 tag）
