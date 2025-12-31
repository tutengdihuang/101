# 完整 DevOps 平台

基于云原生技术栈构建的企业级 DevOps 平台。

## 当前进度

**更新时间**: 2025-12-31

### 已完成
- ✅ Harbor 镜像仓库 (devops namespace) - `http://182.42.82.135:30002`
- ✅ ArgoCD GitOps 部署工具 - `http://182.42.82.135:30090` (admin/admin123)
- ✅ Tekton CI 流水线 (Controller + Webhook + Events Controller)
- ✅ Gitee 仓库配置 (`https://gitee.com/bitcash/service_test.git`)
- ✅ 基础镜像预导入到 Harbor (golang:1.24-alpine, alpine:latest, kaniko:latest)
- ✅ CI Pipeline 完成 - 4 个微服务镜像构建成功

### Harbor 中的镜像
| 镜像 | Tag | 状态 |
|------|-----|------|
| `service-test/user-service` | v1 | ✅ |
| `service-test/product-service` | v1 | ✅ |
| `service-test/trade-service` | v1 | ✅ |
| `service-test/web-service` | v1 | ✅ |
| `service-test/kaniko` | latest | ✅ |
| `library/golang` | 1.24-alpine | ✅ |
| `library/alpine` | latest | ✅ |

### 进行中
- 🔄 ArgoCD Application 配置 (CD 部署)

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
| **Gitee** | 代码仓库 | ✅ 已配置 | `gitee.com/bitcash/service_test` |
| **Harbor** | 镜像仓库 | ✅ 已部署 | `http://182.42.82.135:30002` |
| **ArgoCD** | CD：GitOps 部署 | ✅ 已部署 | `http://182.42.82.135:30090` |
| **Tekton** | CI：构建、推送镜像 | ✅ 已完成 | - |
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
├── 01_gitee/                    # Gitee 配置
├── 02_tekton/                   # Tekton CI 流水线 ✅
│   ├── install/                 # Tekton 安装文件
│   └── pipelines/               # Pipeline/Task 定义
├── 04_argocd/                   # ArgoCD GitOps ✅
│   └── install/                 # ArgoCD 安装文件
├── 05_argo_rollouts/            # Argo Rollouts 渐进式发布
├── 06_sonarqube/                # 代码质量扫描
├── 07_trivy/                    # 镜像漏洞扫描
├── 08_monitoring/               # Prometheus + Grafana
└── config_repo/                 # GitOps 配置仓库
    └── service-test/            # service-test 项目 K8s 配置
```

## 已部署组件详情

### Tekton CI

| 项目 | 值 |
|------|-----|
| **命名空间** | tekton-pipelines |
| **版本** | v1.6.0 |
| **组件** | Controller, Webhook, Events Controller |

**Pipeline 资源**:
- `build-service-v2` Task - 克隆代码 + Kaniko 构建镜像
- `service-test-simple-v2` Pipeline - 并行构建 4 个微服务

**关键配置**:
- 使用 Harbor 作为镜像代理 (`--registry-mirror`)
- Task 超时设置为 2h
- 使用 `--single-snapshot` 和 `--use-new-run` 优化构建速度

### ArgoCD

| 项目 | 值 |
|------|-----|
| **命名空间** | argocd |
| **访问地址** | `http://182.42.82.135:30090` |
| **用户名** | admin |
| **密码** | admin123 |

### Harbor

| 项目 | 值 |
|------|-----|
| **命名空间** | devops |
| **访问地址** | `http://182.42.82.135:30002` |
| **用户名** | admin |
| **密码** | Harbor12345 |
| **项目** | service-test, library |

## 部署顺序

```
阶段 1: 基础设施 ✅
├── Harbor ✅
└── ArgoCD ✅

阶段 2: CI 流水线 ✅
├── Tekton 安装 ✅
├── 基础镜像预导入 ✅
├── Pipeline 资源创建 ✅
└── 4 个微服务镜像构建 ✅

阶段 3: CD 部署 🔄
└── ArgoCD Application 配置

阶段 4: 监控
├── Prometheus
└── Grafana

阶段 5: 安全扫描
├── SonarQube
└── Trivy

阶段 6: 高级发布
└── Argo Rollouts
```

## CI 流程

```
1. 触发 PipelineRun
         │
         ▼
2. build-service-v2 Task (x4 并行):
   ├── Step 1: git clone 从 Gitee 拉取代码
   └── Step 2: Kaniko 构建并推送镜像到 Harbor
         │
         ▼
3. 镜像推送到 Harbor:
   ├── user-service:v1
   ├── product-service:v1
   ├── trade-service:v1
   └── web-service:v1
```

## 快速命令

```bash
# 查看 Tekton 状态
kubectl get pods -n tekton-pipelines
kubectl get pipelinerun,taskrun -n tekton-pipelines

# 查看 Harbor 状态
kubectl get pods -n devops

# 查看 ArgoCD 状态
kubectl get pods -n argocd
kubectl get applications -n argocd

# 触发新的 Pipeline
kubectl create -f 02_tekton/pipelines/pipelinerun-v2.yaml

# 查看 Harbor 镜像
curl -s -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/projects/service-test/repositories
```

## 下一步

1. ~~CI Pipeline 完成~~ ✅
2. 配置 ArgoCD Application 实现 CD
3. 部署 Prometheus + Grafana 监控
4. 部署 Argo Rollouts 实现金丝雀发布
