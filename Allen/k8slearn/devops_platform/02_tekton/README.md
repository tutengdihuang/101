# Tekton CI 部署指南

Tekton 是 Kubernetes 原生的 CI/CD 流水线框架。

## 核心概念

```
┌─────────────────────────────────────────────────────────────┐
│                        Pipeline                              │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │  Task   │───▶│  Task   │───▶│  Task   │───▶│  Task   │  │
│  │ (克隆)  │    │ (扫描)  │    │ (构建)  │    │ (推送)  │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
└─────────────────────────────────────────────────────────────┘
```

| 概念 | 说明 |
|------|------|
| **Task** | 一个任务（如：构建镜像） |
| **Step** | Task 中的步骤 |
| **Pipeline** | 多个 Task 的编排 |
| **PipelineRun** | Pipeline 的一次执行 |
| **Trigger** | 触发器（监听 Webhook） |

## 部署步骤

### 1. 安装 Tekton Pipelines

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# 国内镜像
kubectl apply -f tekton-pipeline.yaml
```

### 2. 安装 Tekton Triggers

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
```

### 3. 安装 Tekton Dashboard（可选）

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
```

### 4. 验证安装

```bash
kubectl get pods -n tekton-pipelines
```

## 目录结构

```
02_tekton/
├── README.md
├── install/
│   ├── tekton-pipeline.yaml      # Tekton Pipelines (国内镜像)
│   ├── tekton-triggers.yaml      # Tekton Triggers
│   └── tekton-dashboard.yaml     # Tekton Dashboard
├── tasks/
│   ├── git-clone.yaml            # 克隆代码
│   ├── sonar-scan.yaml           # 代码扫描
│   ├── docker-build.yaml         # 构建镜像
│   ├── trivy-scan.yaml           # 镜像扫描
│   └── harbor-push.yaml          # 推送镜像
├── pipelines/
│   └── ci-pipeline.yaml          # CI 流水线
└── triggers/
    ├── trigger-template.yaml     # 触发模板
    ├── trigger-binding.yaml      # 参数绑定
    └── event-listener.yaml       # 事件监听
```

## 下一步

1. 创建 Task 定义
2. 创建 Pipeline
3. 配置 Trigger
4. 测试流水线
