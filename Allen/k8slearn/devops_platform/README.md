# 完整 DevOps 平台

基于云原生技术栈构建的企业级 DevOps 平台。

## 当前进度

**更新时间**: 2024-12-28

### 已完成
- ✅ Harbor 镜像仓库 (devops namespace) - `http://<MASTER_IP>:30002`
- ✅ ArgoCD GitOps 部署工具 - `http://<MASTER_IP>:30090` (admin/admin123)
- ✅ Tekton CI 流水线 (Controller + Webhook + Resolvers)
- ✅ Gitee 仓库配置 (`git@gitee.com:bitcash/service_test.git`)
- ✅ 镜像预导入 (entrypoint, busybox, kaniko)
- ✅ Kaniko 镜像推送到 Harbor
- ✅ git-clone Task 执行成功
- ✅ 解决 Tekton 访问仓库验证镜像问题 (显式指定 command)

### 进行中
- 🔄 解决 emptyDir 数据不共享问题 (创建合并的 clone-and-build Task)
- 🔄 ArgoCD Application 配置

### 待部署
- ⏳ Argo Rollouts (金丝雀/蓝绿发布)
- ⏳ Prometheus + Grafana (监控)
- ⏳ SonarQube (代码扫描)
- ⏳ Trivy (镜像扫描)

---

## 架构总览

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           完整 DevOps 平台                                │
│                                                                          │
│  代码 ──▶ Tekton (CI) ──▶ Harbor ──▶ ArgoCD (CD) ──▶ K8s               │
│    │         │              │            │            │                  │
│    │         │              │            │            ▼                  │
│    │         │              │            │      Argo Rollouts           │
│    │         │              │            │      (金丝雀/蓝绿)            │
│    │         │              │            │                               │
│    ▼         ▼              ▼            ▼                               │
│  SonarQube  Trivy        签名验证    Prometheus/Grafana                  │
│  (代码扫描) (镜像扫描)              (监控告警)                            │
└──────────────────────────────────────────────────────────────────────────┘
```

## 组件说明

| 组件 | 职责 | 状态 | 访问地址 |
|------|------|------|----------|
| **Gitee** | 代码仓库（同步 GitHub） | ✅ 已配置 | `gitee.com/bitcash/service_test` |
| **Harbor** | 镜像仓库 | ✅ 已部署 | `http://<MASTER_IP>:30002` |
| **ArgoCD** | CD：GitOps 部署 | ✅ 已部署 | `http://<MASTER_IP>:30090` |
| **Tekton** | CI：构建、测试、推送镜像 | 🔄 进行中 | - |
| **Argo Rollouts** | 金丝雀/蓝绿发布 | ⏳ 待部署 | - |
| **SonarQube** | 代码质量扫描 | ⏳ 待部署 | - |
| **Trivy** | 镜像漏洞扫描 | ⏳ 待部署 | - |
| **Prometheus** | 监控指标收集 | ⏳ 待部署 | - |
| **Grafana** | 监控可视化 | ⏳ 待部署 | - |

## 目录结构

```
devops_platform/
├── README.md                    # 本文档
├── TROUBLESHOOTING.md           # 问题排查指南 ⭐
├── 01_gitee/                    # Gitee 配置（同步 GitHub）
│   └── README.md                # ✅ 已配置
├── 02_tekton/                   # Tekton CI 流水线
│   └── README.md                # 🔄 进行中
├── 03_harbor/                   # Harbor 镜像仓库（已有）
├── 04_argocd/                   # ArgoCD GitOps
│   ├── README.md
│   └── install/                 # ✅ 已部署
│       ├── argocd-crds.yaml
│       ├── argocd-install.yaml
│       ├── argocd-components.yaml
│       └── argocd-default-project.yaml
├── 05_argo_rollouts/            # Argo Rollouts 渐进式发布
├── 06_sonarqube/                # 代码质量扫描
├── 07_trivy/                    # 镜像漏洞扫描
├── 08_monitoring/               # Prometheus + Grafana
└── config_repo/                 # GitOps 配置仓库
    └── service-test/            # service-test 项目配置
```

## 已部署组件详情

### Tekton

| 项目 | 值 |
|------|-----|
| **命名空间** | tekton-pipelines |
| **版本** | v1.6.0 |
| **组件** | Controller, Webhook, Events Controller, Resolvers |

**已创建的 Pipeline 资源**:
- `git-clone` Task - 从 Gitee 拉取代码
- `build-push` Task - 使用 Kaniko 构建镜像
- `service-test-pipeline` Pipeline - 编排 4 个服务构建

**已预导入的镜像** (所有 Worker 节点):
- `ghcr.io/tektoncd/pipeline/entrypoint-xxx:v1.6.0`
- `cgr.dev/chainguard/busybox:latest`
- `gcr.io/kaniko-project/executor:latest`

**Harbor 中的镜像**:
- `182.42.82.135:30002/service-test/kaniko:latest`

**当前卡点**:
- ~~build-push Task 失败: Tekton 控制器访问镜像仓库时 HTTPS/HTTP 不匹配~~ ✅ 已解决
- emptyDir 数据不共享: Clone 和 Build 在不同 Pod，数据无法传递
- 解决方案: 创建合并的 clone-and-build Task

### ArgoCD

| 项目 | 值 |
|------|-----|
| **命名空间** | argocd |
| **访问地址** | `http://<MASTER_IP>:30090` |
| **用户名** | admin |
| **密码** | admin123 |
| **镜像版本** | quay.io/argoproj/argocd:v2.9.3 |

**Pod 状态**:
```
argocd-application-controller   1/1     Running
argocd-redis                    1/1     Running
argocd-repo-server              1/1     Running
argocd-server                   1/1     Running
```

### Harbor

| 项目 | 值 |
|------|-----|
| **命名空间** | devops |
| **访问地址** | `http://<MASTER_IP>:30002` |
| **用户名** | admin |
| **密码** | Harbor12345 |
| **项目** | service-test (公开) |

## 部署顺序

```
阶段 1: 基础设施 ✅
├── Gitee 同步配置 ✅
├── Harbor ✅
└── ArgoCD ✅

阶段 2: CI 流水线 🔄
├── Tekton 安装 ✅
├── Pipeline 资源创建 ✅
├── 镜像预导入 ✅
└── Pipeline 调试 🔄

阶段 3: 监控
├── Prometheus
└── Grafana

阶段 4: 安全扫描
├── SonarQube
└── Trivy

阶段 5: 高级发布
└── Argo Rollouts
```

## 完整流程

```
1. 开发者推送代码到 GitHub
         │
         ▼
2. Gitee 自动同步
         │
         ▼
3. Tekton Trigger 监听 Webhook
         │
         ▼
4. Tekton Pipeline 执行:
   ├── 拉取代码
   ├── SonarQube 代码扫描
   ├── 构建 Docker 镜像
   ├── Trivy 镜像扫描
   └── 推送到 Harbor
         │
         ▼
5. 更新 GitOps 配置仓库 (镜像 tag)
         │
         ▼
6. ArgoCD 检测变更，自动同步
         │
         ▼
7. Argo Rollouts 执行金丝雀发布
         │
         ▼
8. Prometheus 收集指标，Grafana 展示
```

## 资源规划

| 组件 | CPU | 内存 | 存储 | 状态 |
|------|-----|------|------|------|
| ArgoCD | 1.5 核 | 1.5 GB | 1 GB | ✅ |
| Tekton | 1 核 | 1 GB | - | 🔄 |
| Argo Rollouts | 0.5 核 | 256 MB | - | ⏳ |
| SonarQube | 2 核 | 4 GB | 10 GB | ⏳ |
| Trivy | 0.5 核 | 512 MB | - | ⏳ |
| Prometheus | 1 核 | 2 GB | 20 GB | ⏳ |
| Grafana | 0.5 核 | 512 MB | 1 GB | ⏳ |
| **总计** | **~7 核** | **~10 GB** | **~32 GB** | - |

## 下一步

1. ~~配置 Gitee 同步~~ ✅
2. ~~部署 ArgoCD~~ ✅
3. [部署 Tekton](./02_tekton/README.md) 🔄
4. 创建 ArgoCD Application 连接 Gitee 配置仓库
5. 部署 Argo Rollouts
