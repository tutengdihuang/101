# Tekton 深入浅出教程

> 🎯 **一句话定位**：Tekton 是 K8s 原生的 CI/CD 引擎，把构建、测试、部署流程变成 K8s 资源来管理。

## 秒懂 Tekton（30秒版）

**解决什么问题**：
```
传统 CI/CD（Jenkins）：需要单独部署、维护，与 K8s 是两套系统
Tekton：直接运行在 K8s 上，用 YAML 定义流水线，kubectl 就能管理
```

**一句话精华**：
```
Tekton = 把 CI/CD 流水线变成 K8s 资源（CRD）
```

**适合谁学**：已经会 K8s 基础，想搭建云原生 CI/CD 的开发者
**不适合谁**：完全不懂 K8s 的新手（先学 K8s 基础）

---

## 核心概念（用生活比喻理解）

### 概念层级图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Tekton 概念层级                                  │
│                                                                         │
│   🧱 Step (步骤)                                                        │
│      │  最小执行单元 = 一个容器执行一个命令                               │
│      │  比喻：做菜的一个动作（切菜、炒菜、装盘）                           │
│      ▼                                                                  │
│   📦 Task (任务)                                                        │
│      │  一组 Steps = 在同一个 Pod 中顺序执行                             │
│      │  比喻：一道菜的完整做法（包含多个步骤）                            │
│      ▼                                                                  │
│   🔗 Pipeline (流水线)                                                  │
│      │  一组 Tasks = 可以串行或并行执行                                  │
│      │  比喻：一桌宴席（多道菜可以同时做）                                │
│      ▼                                                                  │
│   🚀 PipelineRun (运行实例)                                             │
│         Pipeline 的一次具体执行                                          │
│         比喻：今天这桌宴席的实际制作过程                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 概念速查表

| 概念 | 大白话解释 | 生活比喻 | K8s 对应 |
|------|-----------|---------|----------|
| **Step** | 执行一个命令 | 切菜、炒菜 | Container |
| **Task** | 一组步骤 | 一道菜的做法 | Pod |
| **Pipeline** | 编排多个任务 | 一桌宴席的菜单 | 无直接对应 |
| **PipelineRun** | 一次执行 | 今天做这桌宴席 | Job（类似） |
| **Workspace** | 共享存储 | 厨房的案板 | Volume |

---

## 从你的项目理解 Tekton

### 1. Step（步骤）—— 最小执行单元

**生活比喻**：做菜的一个动作

看你项目中的 `build-service-v2` Task，有两个 Step：

```yaml
steps:
# Step 1: 克隆代码（相当于"准备食材"）
- name: clone
  image: docker.m.daocloud.io/alpine/git:latest  # 用 git 镜像
  command: ["/bin/sh"]
  args:
  - -c
  - |
    git clone $(params.git-url) source    # 执行 git clone
    cd source && git checkout $(params.git-revision)

# Step 2: 构建镜像（相当于"烹饪"）
- name: build-and-push
  image: 182.42.82.135:30002/service-test/kaniko:latest  # 用 kaniko 镜像
  command: ["/kaniko/executor"]
  args:
  - --dockerfile=/workspace/source/$(params.dockerfile)
  - --destination=$(params.image):$(params.tag)
```

**关键点**：
- 每个 Step 是一个容器
- 同一个 Task 的 Steps **顺序执行**
- 同一个 Task 的 Steps **共享 `/workspace` 目录**（这很重要！）

**常见误区** 🚫：
```
❌ 误区：以为每个 Step 是独立的 Pod
✅ 正确：同一个 Task 的所有 Steps 在同一个 Pod 中，共享文件系统

这就像：
❌ 误区：每个厨师在不同的厨房做菜
✅ 正确：所有厨师在同一个厨房，共用同一个案板
```

---

### 2. Task（任务）—— 一组步骤

**生活比喻**：一道菜的完整做法

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-service-v2        # 任务名称（菜名）
spec:
  params:                        # 输入参数（食材清单）
  - name: git-url               # Git 仓库地址
  - name: dockerfile            # Dockerfile 路径
  - name: image                 # 目标镜像名
  - name: tag                   # 镜像标签
  
  steps:                         # 执行步骤（做菜步骤）
  - name: clone                 # 步骤1：克隆代码
  - name: build-and-push        # 步骤2：构建并推送
```

**类比理解**：

```
Task = 函数定义
├── params = 函数参数
├── steps = 函数体
└── 调用时传入具体参数
```

**为什么要用 Task？**
```
场景：你要构建 4 个微服务（user、product、trade、web）
方案1：写 4 个重复的构建脚本 ❌ 重复代码
方案2：写 1 个 Task，调用 4 次，传不同参数 ✅ 复用

这就像：
方案1：写 4 份"红烧肉"食谱（只是肉不同）
方案2：写 1 份"红烧肉"食谱，每次用不同的肉
```

---

### 3. Pipeline（流水线）—— 编排多个任务

**生活比喻**：一桌宴席的菜单

看你项目中的 `service-test-simple-v2` Pipeline：

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: service-test-simple-v2
spec:
  params:                        # Pipeline 级别的参数
  - name: git-url
  - name: image-registry
  - name: image-tag
  
  tasks:                         # 任务列表
  - name: build-user            # 任务1：构建 user-service
    taskRef:
      name: build-service-v2    # 引用哪个 Task
    params:
    - name: dockerfile
      value: dockerfiles/Dockerfile.user
      
  - name: build-product         # 任务2：构建 product-service（并行）
    taskRef:
      name: build-service-v2
    params:
    - name: dockerfile
      value: dockerfiles/Dockerfile.product
      
  - name: build-trade           # 任务3：构建 trade-service（并行）
  - name: build-web             # 任务4：构建 web-service（并行）
```

**关键点**：这 4 个任务**没有依赖关系**，所以会**并行执行**！

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Pipeline 执行示意图                              │
│                                                                         │
│   PipelineRun 开始                                                      │
│         │                                                               │
│         ├──────────┬──────────┬──────────┐                              │
│         ▼          ▼          ▼          ▼                              │
│    build-user  build-product build-trade build-web                      │
│    (Pod 1)     (Pod 2)       (Pod 3)     (Pod 4)                        │
│         │          │          │          │                              │
│         └──────────┴──────────┴──────────┘                              │
│                         │                                               │
│                         ▼                                               │
│                  PipelineRun 完成                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

**如果想串行执行？** 用 `runAfter`：

```yaml
tasks:
- name: build-user
  taskRef:
    name: build-service-v2
    
- name: build-product
  taskRef:
    name: build-service-v2
  runAfter:                      # 等 build-user 完成后再执行
  - build-user
```

---

### 4. PipelineRun（运行实例）—— 一次具体执行

**生活比喻**：今天这桌宴席的实际制作过程

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: service-test-v2-   # 自动生成名称（如 service-test-v2-abc123）
spec:
  pipelineRef:
    name: service-test-simple-v2   # 引用哪个 Pipeline
  params:                           # 传入具体参数
  - name: git-url
    value: https://gitee.com/bitcash/service_test.git
  - name: image-tag
    value: v1
  timeouts:
    pipeline: 3h                    # Pipeline 总超时
    tasks: 2h                       # 单个 Task 超时
```

**类比理解**：

```
Pipeline = 类定义（模板）
PipelineRun = 类的实例（具体执行）

就像：
Pipeline = "红烧肉"食谱
PipelineRun = 今天下午 3 点做的那盘红烧肉
```

**执行时会创建什么 K8s 资源？**

```
PipelineRun: service-test-v2-abc123
├── TaskRun: service-test-v2-abc123-build-user
│   └── Pod: service-test-v2-abc123-build-user-pod
│       ├── Container: step-clone
│       └── Container: step-build-and-push
├── TaskRun: service-test-v2-abc123-build-product
│   └── Pod: ...
├── TaskRun: service-test-v2-abc123-build-trade
│   └── Pod: ...
└── TaskRun: service-test-v2-abc123-build-web
    └── Pod: ...
```

---

## Tekton Triggers —— 自动触发

### 为什么需要 Triggers？

```
没有 Triggers：
  开发者推送代码 → 手动执行 kubectl create -f pipelinerun.yaml → 构建开始

有了 Triggers：
  开发者推送代码 → Gitee 自动发 Webhook → Tekton 自动创建 PipelineRun → 构建开始
```

### Triggers 三剑客

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Tekton Triggers 工作流程                          │
│                                                                         │
│  Gitee Push                                                             │
│      │                                                                  │
│      ▼                                                                  │
│  Webhook POST http://182.42.95.71:30880                                │
│      │  Body: { "after": "abc123", "repository": { "clone_url": "..." }}│
│      ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ EventListener (gitee-listener)                                   │   │
│  │   接收 HTTP 请求，像一个"门卫"                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│      │                                                                  │
│      ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ TriggerBinding (gitee-push-binding)                              │   │
│  │   从请求中提取参数，像一个"翻译官"                                 │   │
│  │   - git-revision = body.after                                    │   │
│  │   - git-repo-url = body.repository.clone_url                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│      │                                                                  │
│      ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ TriggerTemplate (service-test-trigger-template)                  │   │
│  │   用提取的参数创建 PipelineRun，像一个"工厂"                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│      │                                                                  │
│      ▼                                                                  │
│  PipelineRun (service-test-auto-xxx) 自动创建并执行                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1. TriggerBinding —— 翻译官

**作用**：从 Webhook 请求中提取需要的参数

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: gitee-push-binding
spec:
  params:
  - name: git-revision
    value: $(body.after)              # 从 body.after 提取 commit SHA
  - name: git-repo-url
    value: $(body.repository.clone_url)  # 从 body.repository.clone_url 提取仓库 URL
```

**Gitee Webhook 请求示例**：
```json
{
  "after": "abc123def456",           // 最新的 commit SHA
  "repository": {
    "clone_url": "https://gitee.com/bitcash/service_test.git"
  }
}
```

**类比**：
```
Webhook 请求 = 一封外文信
TriggerBinding = 翻译官，把信中的关键信息翻译出来
```

### 2. TriggerTemplate —— 工厂

**作用**：用提取的参数创建 PipelineRun

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: service-test-trigger-template
spec:
  params:
  - name: git-revision
  - name: git-repo-url
  
  resourcetemplates:                  # 要创建的资源模板
  - apiVersion: tekton.dev/v1
    kind: PipelineRun
    metadata:
      generateName: service-test-auto-  # 自动生成名称
    spec:
      pipelineRef:
        name: service-test-simple-v2
      params:
      - name: git-revision
        value: $(tt.params.git-revision)  # 使用 TriggerBinding 提取的参数
      - name: git-url
        value: $(tt.params.git-repo-url)
```

**类比**：
```
TriggerTemplate = 工厂
├── 输入：翻译官提取的参数
├── 输出：一个新的 PipelineRun
└── 每次 Webhook 触发，工厂就生产一个 PipelineRun
```

### 3. EventListener —— 门卫

**作用**：接收 Webhook 请求，调用 Binding 和 Template

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: gitee-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
  - name: gitee-push-trigger
    bindings:
    - ref: gitee-push-binding         # 用哪个翻译官
    template:
      ref: service-test-trigger-template  # 用哪个工厂
```

**类比**：
```
EventListener = 门卫
├── 站在门口（监听 HTTP 请求）
├── 收到信后，交给翻译官（TriggerBinding）
└── 翻译完后，交给工厂（TriggerTemplate）生产 PipelineRun
```

**暴露给外部访问**：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: el-gitee-listener-external
spec:
  type: NodePort
  selector:
    eventlistener: gitee-listener
  ports:
  - port: 8080
    nodePort: 30880    # 外部通过 http://182.42.95.71:30880 访问
```

---

## 完整流程图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Tekton CI 完整流程                                │
│                                                                         │
│  1. 开发者 git push                                                     │
│         │                                                               │
│         ▼                                                               │
│  2. Gitee 发送 Webhook                                                  │
│         │  POST http://182.42.95.71:30880                               │
│         │  Body: { "after": "abc123", "repository": {...} }             │
│         ▼                                                               │
│  3. EventListener 接收请求                                               │
│         │                                                               │
│         ▼                                                               │
│  4. TriggerBinding 提取参数                                              │
│         │  git-revision = "abc123"                                      │
│         │  git-repo-url = "https://gitee.com/..."                       │
│         ▼                                                               │
│  5. TriggerTemplate 创建 PipelineRun                                    │
│         │                                                               │
│         ▼                                                               │
│  6. Pipeline 执行（4 个 Task 并行）                                      │
│         │                                                               │
│         ├── build-user ──────┐                                          │
│         ├── build-product ───┤                                          │
│         ├── build-trade ─────┼──▶ Harbor (镜像仓库)                     │
│         └── build-web ───────┘                                          │
│                                                                         │
│  7. 4 个镜像推送到 Harbor                                                │
│         - service-test/user-service:v1                                  │
│         - service-test/product-service:v1                               │
│         - service-test/trade-service:v1                                 │
│         - service-test/web-service:v1                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 常见问题 FAQ

### Q1: Task 和 Pipeline 有什么区别？

```
Task = 一道菜（多个步骤，同一个 Pod）
Pipeline = 一桌宴席（多道菜，多个 Pod）

Task 内的 Steps：顺序执行，共享文件系统
Pipeline 内的 Tasks：可以并行，不共享文件系统（除非用 Workspace）
```

### Q2: 为什么我的 Task 之间数据不共享？

```
原因：不同 Task 是不同的 Pod，默认不共享文件系统

解决方案：
1. 使用 PVC（持久化存储）
2. 把多个 Step 合并到一个 Task 中
3. 使用 Workspace 配置共享存储
```

### Q3: PipelineRun 和 TaskRun 有什么关系？

```
PipelineRun 创建时，会自动创建多个 TaskRun
每个 TaskRun 对应 Pipeline 中的一个 Task
每个 TaskRun 会创建一个 Pod 来执行

PipelineRun
├── TaskRun 1 → Pod 1
├── TaskRun 2 → Pod 2
└── TaskRun 3 → Pod 3
```

### Q4: 如何查看构建日志？

```bash
# 查看 PipelineRun 状态
kubectl get pipelineruns -n tekton-pipelines

# 查看 TaskRun 状态
kubectl get taskruns -n tekton-pipelines

# 查看具体 Step 的日志
kubectl logs <pod-name> -n tekton-pipelines -c step-clone
kubectl logs <pod-name> -n tekton-pipelines -c step-build-and-push
```

---

## 金句总结

```
📌 Tekton 的本质：把 CI/CD 流水线变成 K8s 资源

📌 核心概念记忆：
   Step = 一个动作（容器）
   Task = 一道菜（Pod）
   Pipeline = 一桌宴席（多个 Pod）
   PipelineRun = 今天做的这桌宴席

📌 Triggers 三剑客：
   EventListener = 门卫（接收请求）
   TriggerBinding = 翻译官（提取参数）
   TriggerTemplate = 工厂（创建 PipelineRun）

📌 一句话带走：
   "Tekton 让你用 kubectl 管理 CI/CD，就像管理 Pod 一样简单"
```

---

## 延伸学习

**想深入学习**：
- [Tekton 官方文档](https://tekton.dev/docs/)
- [Tekton Hub](https://hub.tekton.dev/) - 可复用的 Task 和 Pipeline

**下一步**：
- 学习 ArgoCD，了解 CD（持续部署）部分
- 学习 Tekton Chains，了解软件供应链安全

---

*文档版本：v1.0 | 更新日期：2026-01-02 | 基于项目：service-test CI/CD*
