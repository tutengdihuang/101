# CI/CD 方案组合指南

本文档总结了项目中涉及的 CI/CD 工具及其组合方案。

## 一、工具分类

| 工具 | 类型 | 能否单独使用 | 说明 |
|------|------|-------------|------|
| **GitHub Actions** | CI + CD | ✅ 可以 | 完整的 CI/CD 平台 |
| **Jenkins** | CI + CD | ✅ 可以 | 完整的 CI/CD 平台 |
| **Tekton** | CI + CD | ✅ 可以 | K8s 原生流水线引擎 |
| **ArgoCD** | CD only | ⚠️ 仅 CD | 只负责部署，需配合 CI 工具 |
| **GitLab** | 代码仓库 + CI | ✅ 可以 | 内置 GitLab CI/CD |
| **Harbor** | 镜像仓库 | ❌ 辅助工具 | 存储镜像，不是 CI/CD 工具 |

---

## 二、完整方案组合

### 方案 1：GitHub Actions + 阿里云镜像仓库 (当前使用)

```
代码仓库: GitHub
CI 工具:  GitHub Actions (构建 + 测试 + 打包镜像)
镜像仓库: 阿里云 ACR
CD 工具:  GitHub Actions (kubectl 部署)
```

**流程图**:
```
GitHub Push → GitHub Actions → Build Image → Push to ACR → kubectl apply → K8s Cluster
```

**优点**: 配置简单，云托管免运维  
**适用**: 小团队，GitHub 项目

**配置文件**: `Allen/k8slearn/k8s/ci-cd.yml`

---

### 方案 2：Jenkins + Harbor

```
代码仓库: GitHub/GitLab/任意
CI 工具:  Jenkins (构建 + 测试 + 打包镜像)
镜像仓库: Harbor (私有)
CD 工具:  Jenkins (kubectl/helm 部署)
```

**流程图**:
```
Git Push → Webhook → Jenkins Pipeline → Build Image → Push to Harbor → kubectl apply → K8s Cluster
```

**优点**: 功能强大，插件丰富，完全自主可控  
**适用**: 企业内网，复杂流水线

**配置文件**: `module10/jenkins/`

---

### 方案 3：Tekton + Harbor

```
代码仓库: GitHub/GitLab/任意
CI 工具:  Tekton Pipeline (构建 + 测试 + 打包镜像)
镜像仓库: Harbor (私有)
CD 工具:  Tekton Pipeline (kubectl 部署)
```

**流程图**:
```
Git Push → Tekton Trigger → TaskRun → Build Image → Push to Harbor → kubectl apply → K8s Cluster
```

**优点**: K8s 原生，声明式，可扩展  
**适用**: 云原生团队，K8s 深度用户

**配置文件**: `module10/tekton/`

---

### 方案 4：GitLab CI + Harbor

```
代码仓库: GitLab (自建)
CI 工具:  GitLab CI (构建 + 测试 + 打包镜像)
镜像仓库: Harbor (私有)
CD 工具:  GitLab CI (kubectl 部署)
```

**流程图**:
```
GitLab Push → GitLab Runner → Build Image → Push to Harbor → kubectl apply → K8s Cluster
```

**优点**: 一体化平台，代码和 CI/CD 统一管理  
**适用**: 企业私有化部署

**配置文件**: `module10/tekton/local-gitlab/`

---

### 方案 5：Jenkins/Tekton + ArgoCD (GitOps)

```
代码仓库: GitHub/GitLab
CI 工具:  Jenkins 或 Tekton (构建 + 测试 + 打包镜像 + 更新 Git 配置)
镜像仓库: Harbor / 阿里云 ACR
CD 工具:  ArgoCD (自动同步 Git 配置到 K8s)
```

**流程图**:
```
Git Push → CI Tool → Build Image → Push to Registry → Update Config Repo
                                                            ↓
K8s Cluster ← ArgoCD Sync ← ArgoCD Watch ← Config Repo (Git)
```

**优点**: GitOps 模式，配置即代码，自动漂移检测  
**适用**: 多环境部署，需要审计追踪

**配置文件**: `module10/argocd/`

---

### 方案 6：GitHub Actions + ArgoCD (GitOps)

```
代码仓库: GitHub
CI 工具:  GitHub Actions (构建 + 测试 + 打包镜像 + 更新配置仓库)
镜像仓库: 阿里云 ACR / GHCR
CD 工具:  ArgoCD (监听配置仓库，自动部署)
```

**流程图**:
```
GitHub Push → GitHub Actions → Build Image → Push to Registry → Update Config Repo
                                                                       ↓
K8s Cluster ← ArgoCD Sync ← ArgoCD Watch ← Config Repo (GitHub)
```

**优点**: 云托管 CI + GitOps CD，职责分离  
**适用**: 中大型团队，多集群管理

---

## 三、方案对比

| 方案 | CI 工具 | CD 工具 | 镜像仓库 | 复杂度 | 适用场景 |
|------|---------|---------|----------|--------|----------|
| 方案 1 | GitHub Actions | GitHub Actions | 阿里云 ACR | ⭐ | 小团队/GitHub 项目 |
| 方案 2 | Jenkins | Jenkins | Harbor | ⭐⭐⭐ | 企业内网/复杂流水线 |
| 方案 3 | Tekton | Tekton | Harbor | ⭐⭐⭐ | 云原生团队 |
| 方案 4 | GitLab CI | GitLab CI | Harbor | ⭐⭐ | 企业私有化 |
| 方案 5 | Jenkins/Tekton | ArgoCD | Harbor/ACR | ⭐⭐⭐⭐ | 多环境/GitOps |
| 方案 6 | GitHub Actions | ArgoCD | ACR/GHCR | ⭐⭐⭐ | 中大型团队 |

---

## 四、推荐方案

| 场景 | 推荐方案 |
|------|---------|
| 个人/小团队 + GitHub | **方案 1**: GitHub Actions + 阿里云 ACR |
| 企业内网 + 简单需求 | **方案 2**: Jenkins + Harbor |
| 云原生团队 | **方案 3**: Tekton + Harbor |
| 企业私有化 | **方案 4**: GitLab CI + Harbor |
| 多环境/GitOps | **方案 5/6**: CI工具 + ArgoCD |

---

## 五、项目中已有配置

```
module10/
├── jenkins/              # Jenkins 部署配置
│   ├── jenkins.yaml      # Jenkins StatefulSet
│   └── sa.yaml           # ServiceAccount
├── tekton/               # Tekton 流水线配置
│   ├── task-hello.yaml   # 示例 Task
│   ├── taskrun-hello.yaml
│   ├── git-tasks.yaml
│   ├── github-resource.yaml
│   ├── local-gitlab/     # GitLab + Tekton 集成
│   │   ├── gitlab-deploy.yaml
│   │   ├── gitlab-pipeline.yaml
│   │   └── gitlab.md
│   └── tekton-installation/  # Tekton 安装文件
│       ├── tekton-release.yaml
│       ├── trigger-release.yaml
│       ├── interceptors.yaml
│       └── tekton-dashboard-release.yaml
├── argocd/               # ArgoCD 部署配置
│   ├── argocd.yaml
│   └── readme.MD
└── harbor/               # Harbor 镜像仓库配置
    └── harbor.MD

Allen/k8slearn/
├── k8s/
│   └── ci-cd.yml         # GitHub Actions 配置 (当前使用)
├── CICD_GUIDE.md         # CI/CD 详细指南
└── CICD_README.md        # 本文档
```

---

## 六、快速开始

### 使用当前方案 (GitHub Actions)

1. 将 `k8s/ci-cd.yml` 复制到项目的 `.github/workflows/` 目录
2. 配置 GitHub Secrets:
   - `ALIYUN_REGISTRY_USERNAME`: 阿里云镜像仓库用户名
   - `ALIYUN_REGISTRY_PASSWORD`: 阿里云镜像仓库密码
   - `KUBECONFIG`: K8s 集群配置 (base64 编码)
3. 推送代码触发 CI/CD

### 切换到其他方案

参考 `module10/` 目录下对应工具的配置文件和 README。

---

## 七、相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Jenkins 文档](https://www.jenkins.io/doc/)
- [Tekton 文档](https://tekton.dev/docs/)
- [ArgoCD 文档](https://argo-cd.readthedocs.io/)
- [Harbor 文档](https://goharbor.io/docs/)
- [GitLab CI 文档](https://docs.gitlab.com/ee/ci/)
