# Jenkins + Harbor CI/CD 方案

本方案是 CI/CD 方案组合中的 **方案 2**，适用于企业内网环境和复杂流水线需求。

## 方案定位

### 所有 CI/CD 方案组合

| 方案 | CI 工具 | CD 工具 | 镜像仓库 | 复杂度 | 适用场景 |
|------|---------|---------|----------|--------|----------|
| 方案 1 | GitHub Actions | GitHub Actions | 阿里云 ACR | ⭐ | 小团队/GitHub 项目 |
| **方案 2** | **Jenkins** | **Jenkins** | **Harbor** | ⭐⭐⭐ | **企业内网/复杂流水线** |
| 方案 3 | Tekton | Tekton | Harbor | ⭐⭐⭐ | 云原生团队 |
| 方案 4 | GitLab CI | GitLab CI | Harbor | ⭐⭐ | 企业私有化 |
| 方案 5 | Jenkins/Tekton | ArgoCD | Harbor/ACR | ⭐⭐⭐⭐ | 多环境/GitOps |
| 方案 6 | GitHub Actions | ArgoCD | ACR/GHCR | ⭐⭐⭐ | 中大型团队 |

### 方案简介

| 方案 | 流程 |
|------|------|
| **方案 1** | GitHub Push → GitHub Actions → Build → Push ACR → kubectl → K8s |
| **方案 2** | Git Push → Webhook → Jenkins → Build → Push Harbor → kubectl → K8s |
| **方案 3** | Git Push → Tekton Trigger → TaskRun → Build → Push Harbor → kubectl → K8s |
| **方案 4** | GitLab Push → GitLab Runner → Build → Push Harbor → kubectl → K8s |
| **方案 5** | Git Push → CI Tool → Build → Push Registry → Update Config Repo → ArgoCD Sync → K8s |
| **方案 6** | GitHub Push → Actions → Build → Push Registry → Update Config Repo → ArgoCD Sync → K8s |

### 推荐场景

| 场景 | 推荐方案 |
|------|---------|
| 个人/小团队 + GitHub | 方案 1: GitHub Actions + 阿里云 ACR |
| 企业内网 + 简单需求 | 方案 2: Jenkins + Harbor |
| 云原生团队 | 方案 3: Tekton + Harbor |
| 企业私有化 | 方案 4: GitLab CI + Harbor |
| 多环境/GitOps | 方案 5/6: CI工具 + ArgoCD |

## 方案特点

- **完全自主可控**: Jenkins 和 Harbor 都部署在自己的 K8s 集群
- **功能强大**: Jenkins 插件生态丰富，支持复杂流水线
- **私有镜像仓库**: Harbor 提供企业级镜像管理、漏洞扫描、镜像签名
- **适合内网**: 不依赖外部服务，适合企业内网环境

## 一、架构说明

```
┌─────────────────────────────────────────────────────────────────┐
│                        K8s 集群 (3 节点)                         │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Master 节点 (182.42.82.135)                               │ │
│  │  ├── Jenkins Pod (挂载 Docker Socket)                      │ │
│  │  ├── Docker (用于构建镜像)                                  │ │
│  │  └── Harbor 组件                                           │ │
│  └───────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  devops namespace                                          │ │
│  │  ├── Jenkins (StatefulSet)                                 │ │
│  │  └── Harbor (Helm: core, portal, registry, db, redis...)  │ │
│  └───────────────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  service-test namespace                                    │ │
│  │  └── 业务服务 (user/product/trade/web/etcd)                │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

构建流程:
Git Push → Webhook → Jenkins → Docker Build (Master节点) → Push to Harbor → kubectl deploy → K8s
```

## 二、访问信息

| 服务 | 地址 | 账号 |
|------|------|------|
| **Jenkins** | http://182.42.82.135:30080 | admin / 见下方获取 |
| **Harbor** | http://182.42.82.135:30002 | admin / Harbor12345 |

### 获取 Jenkins 初始密码
```bash
kubectl exec -it jenkins-0 -n devops -- cat /var/jenkins_home/secrets/initialAdminPassword
```

## 三、目录结构

```
jenkins_harbor/
├── README.md                     # 本文档
├── SETUP_GUIDE.md                # 详细部署指南
├── namespace.yaml                # devops 命名空间
├── deploy.sh                     # 一键部署脚本
├── jenkins/
│   ├── jenkins-rbac.yaml         # RBAC 权限
│   ├── jenkins-pvc.yaml          # 持久化存储 (hostPath)
│   ├── jenkins-deployment.yaml   # Jenkins StatefulSet
│   └── jenkins-service.yaml      # Jenkins Service (NodePort 30080)
├── harbor/
│   ├── harbor-values.yaml        # Harbor Helm values (DaoCloud 镜像源)
│   └── harbor-install.sh         # Harbor 安装脚本
├── pipeline/
│   └── Jenkinsfile               # 流水线配置
└── k8s-deployments/
    ├── user-deployment.yaml      # 使用 Harbor 镜像的部署配置
    ├── product-deployment.yaml
    ├── trade-deployment.yaml
    └── web-deployment.yaml
```

## 四、部署状态

### 当前运行的 Pod
```
NAME                                 READY   STATUS    
jenkins-0                            1/1     Running   
harbor-core-xxx                      1/1     Running   
harbor-database-0                    1/1     Running   
harbor-jobservice-xxx                1/1     Running   
harbor-nginx-xxx                     1/1     Running   
harbor-portal-xxx                    1/1     Running   
harbor-redis-0                       1/1     Running   
harbor-registry-xxx                  2/2     Running   
```

### 已完成配置
- ✅ Jenkins 部署在 Master 节点 (使用 nodeSelector)
- ✅ Jenkins 挂载 Docker Socket (可构建镜像)
- ✅ Harbor 部署完成 (使用 DaoCloud 国内镜像源)
- ✅ Harbor 项目 `service-test` 已创建 (公开)
- ✅ Master 节点安装 Docker
- ✅ Docker 配置信任 Harbor (insecure-registries)
- ✅ 所有节点 containerd 配置信任 Harbor

## 五、关键配置说明

### 5.1 镜像源配置
由于国内网络限制，使用 DaoCloud 镜像源：
- Jenkins: `docker.m.daocloud.io/jenkins/jenkins:lts-jdk17`
- Harbor: `docker.m.daocloud.io/goharbor/*`

### 5.2 Docker Socket 挂载
Jenkins Pod 挂载 Master 节点的 Docker Socket：
```yaml
volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
      type: Socket
  - name: docker-bin
    hostPath:
      path: /usr/bin/docker
      type: File
```

### 5.3 Harbor 信任配置
Master 节点 `/etc/docker/daemon.json`:
```json
{"insecure-registries":["182.42.82.135:30002"]}
```

所有节点 `/etc/containerd/config.toml` 添加:
```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."182.42.82.135:30002"]
  endpoint = ["http://182.42.82.135:30002"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."182.42.82.135:30002".tls]
  insecure_skip_verify = true
```

## 六、快速验证

### 验证 Jenkins 可以使用 Docker
```bash
kubectl exec jenkins-0 -n devops -- docker version
```

### 验证 Jenkins 可以登录 Harbor
```bash
kubectl exec jenkins-0 -n devops -- docker login 182.42.82.135:30002 -u admin -p Harbor12345
```

### 验证 Harbor API
```bash
curl -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/projects
```

## 七、下一步配置

1. **访问 Jenkins** http://182.42.82.135:30080
2. **完成初始化向导** (使用初始密码)
3. **安装插件**: Docker Pipeline, Git, Pipeline, Kubernetes, GitHub
4. **配置 Harbor 凭证**:
   - Manage Jenkins → Credentials → Add
   - Kind: Username with password
   - Username: admin
   - Password: Harbor12345
   - ID: harbor-credentials
5. **创建 Pipeline 项目** 使用 `pipeline/Jenkinsfile`

## 八、GitHub Webhook 配置 (内网穿透)

由于 Jenkins 部署在内网，GitHub 无法直接访问，需要使用 smee.io 做 Webhook 代理。

### 8.1 架构

```
GitHub → smee.io (公网代理) → smee-client (Master节点) → Jenkins (内网)
```

### 8.2 配置步骤

1. **获取 smee.io 通道**
   - 访问 https://smee.io/new
   - 复制生成的 URL，如: `https://smee.io/xxxxxx`

2. **在 Master 节点运行 smee-client**
   ```bash
   # 安装 (需要 Node.js 18+)
   npm install -g smee-client
   
   # 运行 (后台)
   nohup smee -u https://smee.io/YOUR_CHANNEL -t http://localhost:30080/github-webhook/ &
   ```

3. **配置 GitHub Webhook**
   - 进入 GitHub 仓库 → Settings → Webhooks → Add webhook
   - Payload URL: `https://smee.io/YOUR_CHANNEL`
   - Content type: `application/json`
   - Events: `Just the push event`

4. **配置 Jenkins Job**
   - 在 Pipeline 配置中勾选 "GitHub hook trigger for GITScm polling"
   - 或在 Jenkinsfile 中使用:
   ```groovy
   triggers {
       githubPush()
   }
   ```

### 8.3 替代方案

如果 smee.io 不稳定，可以考虑:
- **ngrok**: `ngrok http 30080`
- **frp**: 自建内网穿透服务
- **pollSCM**: 定时轮询 (当前配置，每 2 分钟检查一次)

## 九、相关文档

- [SETUP_GUIDE.md](./SETUP_GUIDE.md) - 详细部署步骤和问题排查
- [pipeline/Jenkinsfile](./pipeline/Jenkinsfile) - 流水线配置
- [../CICD_README.md](../CICD_README.md) - 所有 CI/CD 方案对比
