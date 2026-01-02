# 完整 DevOps 平台

基于云原生技术栈构建的企业级 DevOps 平台。

## 当前进度

**更新时间**: 2026-01-01

### 已完成
- ✅ Harbor 镜像仓库 (devops namespace) - `http://182.42.82.135:30002`
- ✅ ArgoCD GitOps 部署工具 - `http://182.42.82.135:30090` (admin/admin123)
- ✅ Tekton CI 流水线 (Controller + Webhook + Triggers)
- ✅ Tekton Triggers 自动触发 (Gitee Webhook → EventListener)
- ✅ Gitee 仓库配置 (`https://gitee.com/bitcash/service_test.git`)
- ✅ 基础镜像预导入到 Harbor (golang:1.24-alpine, alpine:latest, kaniko:latest)
- ✅ CI Pipeline 完成 - 4 个微服务镜像构建成功
- ✅ ArgoCD Application 配置 (CD 部署) - 4 个微服务自动部署成功
- ✅ **完整 CI/CD 自动化流程验证通过**

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

### 待部署
- 🔧 Argo Rollouts (金丝雀/蓝绿发布) - **配置已就绪，待安装**
- ⏳ Prometheus + Grafana (监控)
- ⏳ SonarQube (代码扫描)
- ⏳ Trivy (镜像扫描)

---

## 架构总览

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           完整 DevOps 平台                                │
│                                                                          │
│  代码推送                                                                 │
│    │                                                                     │
│    ▼                                                                     │
│  Gitee ──(Webhook)──▶ Tekton Triggers ──▶ Tekton Pipeline (CI)          │
│                              │                    │                      │
│                              │                    ▼                      │
│                              │              Harbor (镜像仓库)             │
│                              │                    │                      │
│                              ▼                    ▼                      │
│                         ArgoCD (CD) ◀── 监听 Git 仓库 k8s 配置           │
│                              │                                           │
│                              ▼                                           │
│                         K8s 集群 (自动部署)                               │
│                              │                                           │
│                              ▼                                           │
│                      Argo Rollouts (金丝雀/蓝绿) [待部署]                 │
│                                                                          │
│  监控: Prometheus/Grafana [待部署]                                        │
│  安全: SonarQube + Trivy [待部署]                                         │
└──────────────────────────────────────────────────────────────────────────┘
```

## 组件说明

| 组件 | 职责 | 状态 | 访问地址 |
|------|------|------|----------|
| **Gitee** | 代码仓库 | ✅ 已配置 | `gitee.com/bitcash/service_test` |
| **Harbor** | 镜像仓库 | ✅ 已部署 | `http://182.42.82.135:30002` |
| **ArgoCD** | CD：GitOps 部署 | ✅ 已部署 | `http://182.42.82.135:30090` |
| **Tekton** | CI：构建、推送镜像 | ✅ 已完成 | - |
| **Tekton Triggers** | CI 自动触发 | ✅ 已完成 | `http://182.42.95.71:30880` |
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
│   ├── pipelines/               # Pipeline/Task 定义
│   └── triggers/                # Tekton Triggers 配置 ✅
├── 04_argocd/                   # ArgoCD GitOps ✅
│   ├── install/                 # ArgoCD 安装文件
│   └── applications/            # Application 配置
├── 05_argo_rollouts/            # Argo Rollouts 渐进式发布
├── 06_sonarqube/                # 代码质量扫描
├── 07_trivy/                    # 镜像漏洞扫描
├── 08_monitoring/               # Prometheus + Grafana
└── k8s/                         # K8s 部署配置
    ├── configmaps.yaml
    ├── user/deployment.yaml
    ├── product/deployment.yaml
    ├── trade/deployment.yaml
    └── web/deployment.yaml
```

## 已部署组件详情

### Tekton CI + Triggers

| 项目 | 值 |
|------|-----|
| **命名空间** | tekton-pipelines |
| **版本** | Pipeline v1.6.0, Triggers v0.34.0 |
| **组件** | Controller, Webhook, Triggers Controller, EventListener |

**Pipeline 资源**:
- `build-service-v2` Task - 克隆代码 + Kaniko 构建镜像
- `service-test-simple-v2` Pipeline - 并行构建 4 个微服务

**Triggers 资源**:
- `gitee-listener` EventListener - 接收 Gitee Webhook
- `gitee-push-binding` TriggerBinding - 提取 git-revision 和 git-repo-url
- `service-test-trigger-template` TriggerTemplate - 创建 PipelineRun

**关键配置**:
- 使用 Harbor 作为镜像代理 (`--registry-mirror`)
- Task 超时设置为 2h
- 使用 `--single-snapshot` 和 `--use-new-run` 优化构建速度
- Webhook 地址: `http://182.42.95.71:30880`

### ArgoCD

| 项目 | 值 |
|------|-----|
| **命名空间** | argocd |
| **访问地址** | `http://182.42.82.135:30090` |
| **用户名** | admin |
| **密码** | admin123 |
| **Application** | service-test (自动同步 Gitee k8s 目录) |

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
├── Tekton Triggers 安装 ✅
├── 基础镜像预导入 ✅
├── Pipeline 资源创建 ✅
├── Triggers 资源创建 ✅
├── Gitee Webhook 配置 ✅
└── 4 个微服务镜像构建 ✅

阶段 3: CD 部署 ✅
├── ArgoCD Application 配置 ✅
└── 自动同步验证 ✅

阶段 4: 监控 (待部署)
├── Prometheus
└── Grafana

阶段 5: 安全扫描 (待部署)
├── SonarQube
└── Trivy

阶段 6: 高级发布 (待部署)
└── Argo Rollouts
```

## CI/CD 完整流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        完整 CI/CD 自动化流程                             │
│                                                                         │
│  1. 开发者推送代码到 Gitee                                               │
│     │                                                                   │
│     ▼                                                                   │
│  2. Gitee Webhook 触发 (POST http://182.42.95.71:30880)                 │
│     │                                                                   │
│     ▼                                                                   │
│  3. Tekton EventListener 接收请求                                        │
│     │                                                                   │
│     ├── TriggerBinding 提取参数 (git-revision, git-repo-url)            │
│     │                                                                   │
│     └── TriggerTemplate 创建 PipelineRun                                │
│         │                                                               │
│         ▼                                                               │
│  4. Pipeline 执行 (4 个 Task 并行)                                       │
│     ├── build-user: git clone + kaniko build → Harbor                   │
│     ├── build-product: git clone + kaniko build → Harbor                │
│     ├── build-trade: git clone + kaniko build → Harbor                  │
│     └── build-web: git clone + kaniko build → Harbor                    │
│         │                                                               │
│         ▼                                                               │
│  5. 镜像推送到 Harbor (service-test/xxx:v1)                              │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  6. ArgoCD 监听 Gitee k8s 目录变化 (每 3 分钟轮询)                        │
│     │                                                                   │
│     ▼                                                                   │
│  7. 自动同步 K8s 资源到集群                                               │
│     │                                                                   │
│     ▼                                                                   │
│  8. 服务部署完成，可通过 http://182.42.82.135:30888 访问                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## 快速命令

```bash
# === CI 相关 ===
# 查看 Tekton 状态
kubectl get pods -n tekton-pipelines
kubectl get pipelinerun,taskrun -n tekton-pipelines

# 查看 Triggers 状态
kubectl get pods -n tekton-pipelines | grep -E "trigger|listener"
kubectl get eventlisteners,triggertemplates,triggerbindings -n tekton-pipelines

# 手动触发 Pipeline (如果需要)
kubectl create -f 02_tekton/pipelines/pipelinerun-v2.yaml

# === CD 相关 ===
# 查看 ArgoCD 状态
kubectl get pods -n argocd
kubectl get applications -n argocd

# 手动触发 ArgoCD 同步
kubectl annotate application service-test -n argocd argocd.argoproj.io/refresh=hard --overwrite

# === Harbor 相关 ===
kubectl get pods -n devops
curl -s -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/projects/service-test/repositories

# === 服务相关 ===
kubectl get pods -n service-test
curl http://182.42.82.135:30888/api/user/1
```

## 服务访问

| 服务 | 访问地址 | 说明 |
|------|----------|------|
| Harbor | http://182.42.82.135:30002 | admin/Harbor12345 |
| ArgoCD | http://182.42.82.135:30090 | admin/admin123 |
| Tekton Webhook | http://182.42.95.71:30880 | Gitee Webhook 地址 |
| Web API | http://182.42.82.135:30888 | 微服务 API 入口 |

## 下一步

1. ~~CI Pipeline 完成~~ ✅
2. ~~Tekton Triggers 自动触发~~ ✅
3. ~~ArgoCD Application 配置~~ ✅
4. ~~完整 CI/CD 流程验证~~ ✅
5. **安装 Argo Rollouts 实现金丝雀发布** ← 当前
6. 部署 Prometheus + Grafana 监控
