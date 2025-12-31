# DevOps 平台问题排查指南

记录部署和使用过程中遇到的问题及解决方案。

---

## 问题 1: ArgoCD 镜像拉取失败 (403 Forbidden)

**现象**:
```
Failed to pull image "docker.m.daocloud.io/argoproj/argocd:v2.9.3": 
unexpected status from HEAD request: 403 Forbidden
```

**原因**: DaoCloud 镜像仓库对某些镜像有访问限制

**解决方案**: 改用 quay.io 官方镜像
```yaml
# 修改前
image: docker.m.daocloud.io/argoproj/argocd:v2.9.3

# 修改后
image: quay.io/argoproj/argocd:v2.9.3
```

**操作步骤**:
```bash
# 1. 修改 YAML 文件中的镜像地址
sed -i 's|docker.m.daocloud.io/argoproj/argocd|quay.io/argoproj/argocd|g' argocd-components.yaml

# 2. 重新应用配置
kubectl apply -f argocd-components.yaml

# 3. 重启 deployment
kubectl rollout restart deployment -n argocd
```

---

## 问题 2: ArgoCD 登录失败 (Invalid username or password)

**现象**: 使用 admin 账号登录 ArgoCD UI 时提示 "Invalid username or password"

**原因**: 密码 hash 格式不正确，ArgoCD 使用 bcrypt 格式的密码 hash

**解决方案**: 使用 htpasswd 生成正确格式的密码 hash

**操作步骤**:
```bash
# 1. 安装 htpasswd 工具
apt-get install -y apache2-utils   # Ubuntu/Debian
# 或
yum install -y httpd-tools         # CentOS/RHEL

# 2. 生成 bcrypt 密码 hash (将 $2y 替换为 $2a)
HASH=$(htpasswd -nbBC 10 "" admin123 | tr -d ":\n" | sed 's/$2y/$2a/')

# 3. 更新 ArgoCD secret
kubectl -n argocd patch secret argocd-secret -p "{\"stringData\": {\"admin.password\": \"$HASH\", \"admin.passwordMtime\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"

# 4. 重启 argocd-server
kubectl rollout restart deployment argocd-server -n argocd

# 5. 等待 Pod 就绪
kubectl get pods -n argocd -w
```

**验证**:
- 访问 `http://<MASTER_IP>:30090`
- 用户名: `admin`
- 密码: `admin123`

---

## 问题 3: ArgoCD Pod 状态 ImagePullBackOff

**现象**:
```
argocd-server-xxx   0/1   ImagePullBackOff   0   2m
```

**排查步骤**:
```bash
# 1. 查看 Pod 详情
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server

# 2. 查看事件中的错误信息
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

**常见原因及解决**:

| 原因 | 解决方案 |
|------|----------|
| 镜像仓库不可访问 | 更换镜像源 (quay.io, gcr.io) |
| 镜像 tag 不存在 | 检查版本号是否正确 |
| 网络问题 | 检查节点网络连通性 |
| 镜像仓库认证失败 | 配置 imagePullSecrets |

---

## 问题 4: ArgoCD 无法连接 Git 仓库

**现象**: Application 状态显示 "ComparisonError" 或 "Unable to connect to repository"

**排查步骤**:
```bash
# 1. 检查 repo-server 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# 2. 测试 Git 连接
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote https://gitee.com/bitcash/service_test.git
```

**解决方案**:

1. **公开仓库**: 确保仓库是公开的，或配置访问凭证
2. **私有仓库**: 在 ArgoCD 中添加仓库凭证
   ```bash
   # 通过 UI: Settings -> Repositories -> Connect Repo
   # 或通过 CLI:
   argocd repo add https://gitee.com/bitcash/service_test.git --username <user> --password <token>
   ```

---

## 问题 5: ArgoCD Application 同步失败

**现象**: Application 状态为 "OutOfSync" 或 "SyncFailed"

**排查步骤**:
```bash
# 1. 查看 Application 状态
kubectl get application -n argocd
kubectl describe application <app-name> -n argocd

# 2. 查看同步详情
kubectl get application <app-name> -n argocd -o yaml | grep -A 20 status
```

**常见原因**:
- K8s 配置文件语法错误
- 目标 namespace 不存在
- RBAC 权限不足
- 资源已存在且有冲突

---

## 快速诊断命令

```bash
# ArgoCD 整体状态
kubectl get pods,svc -n argocd

# 查看所有 Application
kubectl get applications -n argocd

# 查看 ArgoCD 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50

# 检查 CRD
kubectl get crd | grep argoproj
```

---

## 相关文档

- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [ArgoCD FAQ](https://argo-cd.readthedocs.io/en/stable/faq/)


---

## 问题 6: Tekton 镜像拉取失败 (gcr.io 需要认证)

**现象**:
```
Failed to pull image "gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/controller:v0.53.0": 
denied: Unauthenticated request
```

**原因**: gcr.io 从 2024 年开始需要认证，Tekton 已迁移到 ghcr.io

**解决方案**: 

方案 1 - 使用最新版本 (推荐)：
```bash
# 最新版本已迁移到 ghcr.io
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

方案 2 - 本地拉取后传到服务器：
```bash
# 1. 本地设置代理拉取镜像
export https_proxy=http://127.0.0.1:7890
docker pull ghcr.io/tektoncd/pipeline/controller-xxx:v1.6.0
docker pull ghcr.io/tektoncd/pipeline/webhook-xxx:v1.6.0

# 2. 保存镜像
docker save <image> -o /tmp/tekton-controller.tar

# 3. 传到服务器
scp /tmp/tekton-*.tar root@<SERVER_IP>:/tmp/

# 4. 在服务器上导入到 containerd
ctr -n k8s.io images import /tmp/tekton-controller.tar
```

方案 3 - 推送到私有 Harbor：
```bash
# 1. 配置 Docker 信任 HTTP 仓库
# Docker Desktop -> Settings -> Docker Engine
# 添加: "insecure-registries": ["<HARBOR_IP>:30002"]

# 2. 重新 tag 并推送
docker tag ghcr.io/tektoncd/xxx 182.42.82.135:30002/service-test/tekton-controller:v1.6.0
docker push 182.42.82.135:30002/service-test/tekton-controller:v1.6.0

# 3. 修改 Tekton YAML 使用 Harbor 镜像
```

---

## 问题 7: Docker 推送到 Harbor 失败 (HTTP/HTTPS 问题)

**现象**:
```
Get "https://182.42.82.135:30002/v2/": http: server gave HTTP response to HTTPS client
```

**原因**: Harbor 使用 HTTP，但 Docker 默认使用 HTTPS

**解决方案**:

**Docker Desktop (macOS/Windows)**:
1. 打开 Docker Desktop → Settings → Docker Engine
2. 添加 `insecure-registries`:
```json
{
  "insecure-registries": ["182.42.82.135:30002"]
}
```
3. 点击 Apply & Restart

**Linux Docker**:
```bash
# 编辑 /etc/docker/daemon.json
{
  "insecure-registries": ["182.42.82.135:30002"]
}

# 重启 Docker
systemctl restart docker
```

---

## 问题 8: SCP 传输大文件到服务器很慢

**现象**: 传输 100MB+ 的镜像文件速度很慢或卡住

**解决方案**:

方案 1 - 压缩后传输：
```bash
gzip /tmp/tekton-controller.tar
scp /tmp/tekton-controller.tar.gz root@<SERVER>:/tmp/
ssh root@<SERVER> 'gunzip /tmp/tekton-controller.tar.gz'
```

方案 2 - 使用 rsync：
```bash
rsync -avz --progress /tmp/tekton-*.tar root@<SERVER>:/tmp/
```

方案 3 - 推送到 Harbor 后服务器拉取：
```bash
# 本地推送到 Harbor
docker push <HARBOR>/tekton-controller:v1.6.0

# 服务器直接拉取
crictl pull <HARBOR>/tekton-controller:v1.6.0
```

---

## 问题 9: DaoCloud 镜像代理 403 Forbidden

**现象**:
```
unexpected status from HEAD request to https://docker.m.daocloud.io/v2/xxx: 403 Forbidden
```

**原因**: DaoCloud 对部分镜像有访问限制

**解决方案**:

| 原镜像 | 替代方案 |
|--------|----------|
| docker.m.daocloud.io/argoproj/argocd | quay.io/argoproj/argocd |
| gcr.m.daocloud.io/tekton-releases/xxx | ghcr.io/tektoncd/xxx (最新版) |
| docker.m.daocloud.io/library/xxx | 直接用 library/xxx |

**其他可用镜像源**:
- `quay.io` - Red Hat 镜像仓库
- `ghcr.io` - GitHub Container Registry
- `registry.cn-hangzhou.aliyuncs.com` - 阿里云

---

## 快速诊断命令汇总

```bash
# 查看所有 DevOps 组件状态
kubectl get pods -n tekton-pipelines
kubectl get pods -n argocd
kubectl get pods -n devops

# 查看镜像拉取错误
kubectl describe pod <pod-name> -n <namespace> | tail -20

# 查看 Tekton CRD
kubectl get crd | grep tekton

# 查看 ArgoCD 应用
kubectl get applications -n argocd

# 测试 Harbor 连接
curl -u admin:Harbor12345 http://<MASTER_IP>:30002/api/v2.0/projects
```


---

## 问题 10: Tekton PipelineRun API 版本错误

**现象**:
```
PipelineRun in version "v1" cannot be handled as a PipelineRun: 
strict decoding error: unknown field "spec.serviceAccountName"
```

**原因**: Tekton v1 API 中 `serviceAccountName` 字段位置变更

**解决方案**:
```yaml
# 错误写法 (v1beta1 风格)
spec:
  serviceAccountName: tekton-build-sa

# 正确写法 (v1 风格)
spec:
  taskRunTemplate:
    serviceAccountName: tekton-build-sa
```

---

## 问题 11: Tekton TaskRun PodSecurity 限制

**现象**:
```
pods "xxx" is forbidden: violates PodSecurity "restricted:latest": 
allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true
```

**原因**: K8s 1.25+ 默认启用 Pod Security Standards，tekton-pipelines namespace 使用 restricted 策略

**解决方案**:
```bash
# 将 namespace 设置为 privileged 策略
kubectl label namespace tekton-pipelines pod-security.kubernetes.io/enforce=privileged --overwrite
```

**注意**: 生产环境应该给 Task 添加 securityContext 而不是放宽整个 namespace

---

## 问题 12: Tekton PipelineRun PVC 无法绑定

**现象**:
```
0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims
```

**原因**: 集群没有配置 StorageClass，无法动态创建 PV

**解决方案**:

方案 1 - 使用 emptyDir (简单，但数据不持久):
```yaml
workspaces:
- name: shared-workspace
  emptyDir: {}
```

方案 2 - 配置 StorageClass (推荐生产环境):
```bash
# 安装 local-path-provisioner 或其他存储方案
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

---

## 问题 13: 本地 Mac 与服务器架构不匹配

**现象**: 本地拉取的镜像上传到服务器后无法运行

**原因**: 
- Mac M1/M2 是 arm64 架构
- 服务器是 x86_64 (amd64) 架构

**解决方案**:
```bash
# 拉取时指定平台
docker pull --platform linux/amd64 <image>

# 验证架构
docker inspect <image> | grep Architecture
```

---

## 问题 14: containerd 镜像 digest 不匹配

**现象**: 镜像已导入但 Pod 仍然 ImagePullBackOff

**原因**: K8s 请求的是带 `@sha256:xxx` 的镜像，但导入的镜像只有 tag

**解决方案**:
```bash
# 为镜像创建带 digest 的别名
ctr -n k8s.io images tag \
  ghcr.io/tektoncd/pipeline/entrypoint-xxx:v1.6.0 \
  "ghcr.io/tektoncd/pipeline/entrypoint-xxx@sha256:255ea8fadab1481fbd1e562d9ac7d4008cd9515de5f952647c8959028c8990a0"
```

---

## 问题 15: 镜像只在部分节点可用

**现象**: Pod 调度到没有镜像的节点时 ImagePullBackOff

**原因**: 手动导入的镜像只存在于导入的那个节点

**解决方案**:

方案 1 - 在所有 Worker 节点导入:
```bash
# 传输到所有节点
for node in 182.42.80.121 182.42.95.71; do
  scp /tmp/image.tar.gz root@$node:/tmp/
  ssh root@$node 'gunzip -c /tmp/image.tar.gz | ctr -n k8s.io images import --all-platforms -'
done
```

方案 2 - 推送到 Harbor 让节点自动拉取:
```bash
docker tag <image> <harbor>/project/<image>
docker push <harbor>/project/<image>
```

方案 3 - 使用 nodeSelector 固定调度:
```yaml
spec:
  nodeSelector:
    kubernetes.io/hostname: k8s-worker1
```

---

## 问题 16: 镜像传输到服务器的完整流程

**场景**: 国内服务器无法拉取 ghcr.io/gcr.io 镜像

**完整步骤**:
```bash
# 1. 本地设置代理
export https_proxy=http://127.0.0.1:7890

# 2. 拉取 amd64 架构镜像
docker pull --platform linux/amd64 ghcr.io/xxx:tag

# 3. 压缩保存 (减少传输时间)
docker save ghcr.io/xxx:tag | gzip > /tmp/image.tar.gz

# 4. 上传到服务器
scp /tmp/image.tar.gz root@<SERVER>:/tmp/

# 5. 在服务器上导入到 containerd
ssh root@<SERVER> 'gunzip -c /tmp/image.tar.gz | ctr -n k8s.io images import --all-platforms -'

# 6. 如果需要 digest 别名
ssh root@<SERVER> 'ctr -n k8s.io images tag <image>:tag "<image>@sha256:xxx"'

# 7. 验证
ssh root@<SERVER> 'ctr -n k8s.io images ls | grep <image>'
```

---

## Tekton 相关命令速查

```bash
# 查看 Pipeline
kubectl get pipelines -n tekton-pipelines

# 查看 Task
kubectl get tasks -n tekton-pipelines

# 查看 PipelineRun 状态
kubectl get pipelineruns -n tekton-pipelines

# 查看 TaskRun 状态
kubectl get taskruns -n tekton-pipelines

# 查看 PipelineRun 详情
kubectl describe pipelinerun <name> -n tekton-pipelines

# 查看 TaskRun 日志
kubectl logs <taskrun-pod> -n tekton-pipelines -c step-<step-name>

# 删除所有 PipelineRun
kubectl delete pipelineruns --all -n tekton-pipelines

# 查看 Tekton 组件状态
kubectl get pods -n tekton-pipelines
```


---

## 问题 17: Tekton 创建 Pod 时访问镜像仓库超时

**现象**:
```
failed to create task run pod "xxx": translating TaskSpec to Pod: 
Get "https://gcr.io/v2/": dial tcp xxx:443: i/o timeout
```

**原因**: Tekton 在创建 Pod 时会访问镜像仓库验证镜像是否存在，即使镜像已在本地节点

**解决方案**:

方案 1 - 添加 imagePullPolicy:
```yaml
steps:
- name: build-and-push
  image: gcr.io/kaniko-project/executor:latest
  imagePullPolicy: IfNotPresent  # 添加这行
```

方案 2 - 使用本地 Harbor 镜像:
```yaml
# 将镜像推送到 Harbor 后使用
image: 182.42.82.135:30002/service-test/kaniko:latest
```

方案 3 - 配置 Tekton feature flags:
```bash
kubectl edit configmap feature-flags -n tekton-pipelines
# 添加: disable-creds-init: "true"
```

---

## 问题 18: Tekton Pipeline Clone 成功但 Build 失败

**现象**: git-clone TaskRun 成功，但后续 build TaskRun 显示 PodCreationFailed

**排查步骤**:
```bash
# 1. 查看 TaskRun 状态
kubectl get taskruns -n tekton-pipelines

# 2. 查看失败原因
kubectl describe taskrun <taskrun-name> -n tekton-pipelines | tail -20

# 3. 常见原因
# - 镜像拉取失败 (网络问题)
# - Secret 不存在
# - Workspace 配置错误
```

**常见原因及解决**:

| 原因 | 解决方案 |
|------|----------|
| 镜像仓库不可访问 | 预导入镜像到所有节点 |
| Harbor Secret 错误 | 检查 dockerconfigjson 格式 |
| emptyDir 数据丢失 | 确保 build 和 clone 在同一 Pod 或使用 PVC |

---

## 镜像预导入完整流程

**场景**: 国内服务器无法访问 gcr.io/ghcr.io，需要预先导入镜像

**步骤**:

```bash
# === 本地 Mac (有代理) ===

# 1. 设置代理
export https_proxy=http://127.0.0.1:7890

# 2. 拉取 amd64 架构镜像
docker pull --platform linux/amd64 gcr.io/kaniko-project/executor:latest

# 3. 压缩保存
docker save gcr.io/kaniko-project/executor:latest | gzip > /tmp/kaniko.tar.gz

# 4. 上传到所有节点
for node in 182.42.82.135 182.42.80.121 182.42.95.71; do
  scp /tmp/kaniko.tar.gz root@$node:/tmp/
done

# === 服务器端 ===

# 5. 导入到 containerd
for node in 182.42.82.135 182.42.80.121 182.42.95.71; do
  ssh root@$node 'gunzip -c /tmp/kaniko.tar.gz | ctr -n k8s.io images import --all-platforms -'
done

# 6. 验证
ssh root@182.42.82.135 'ctr -n k8s.io images ls | grep kaniko'
```

**已预导入的镜像清单**:

| 镜像 | 用途 | 大小 |
|------|------|------|
| `ghcr.io/tektoncd/pipeline/entrypoint-xxx:v1.6.0` | Tekton 步骤调度 | ~40MB |
| `cgr.dev/chainguard/busybox:latest` | 脚本执行 | ~4MB |
| `gcr.io/kaniko-project/executor:latest` | Docker 镜像构建 | ~34MB |
| `docker.m.daocloud.io/alpine/git:latest` | Git 操作 | ~10MB |

---

## Tekton Pipeline 调试命令

```bash
# 查看 Pipeline 执行状态
kubectl get pipelineruns -n tekton-pipelines

# 查看所有 TaskRun
kubectl get taskruns -n tekton-pipelines

# 查看 TaskRun 详情
kubectl describe taskrun <name> -n tekton-pipelines

# 查看 TaskRun Pod 日志
kubectl logs <taskrun-pod> -n tekton-pipelines --all-containers

# 查看特定步骤日志
kubectl logs <taskrun-pod> -n tekton-pipelines -c step-clone

# 删除所有 PipelineRun 重新测试
kubectl delete pipelineruns --all -n tekton-pipelines

# 手动创建 PipelineRun
kubectl create -f pipelinerun-example.yaml
```


---

## 问题 19: Tekton 访问 Harbor 时 HTTPS/HTTP 不匹配

**现象**:
```
failed to create task run pod "xxx": translating TaskSpec to Pod: 
Get "https://182.42.82.135:30002/v2/": http: server gave HTTP response to HTTPS client
```

**原因**: Tekton 控制器在解析镜像时默认使用 HTTPS，但 Harbor 配置的是 HTTP

**解决方案**:

方案 1 - 使用公共镜像仓库的镜像:
```yaml
# 使用 DaoCloud 镜像加速
image: docker.m.daocloud.io/bitnami/kaniko:latest

# 或使用 Docker Hub
image: bitnami/kaniko:latest
```

方案 2 - 为 Harbor 配置 HTTPS:
```bash
# 需要配置 TLS 证书，较复杂
```

方案 3 - 配置 Tekton 信任 HTTP 仓库:
```bash
# 需要修改 Tekton 控制器配置，较复杂
```

**推荐**: 对于 Tekton 使用的工具镜像（如 Kaniko、Git），使用公共镜像仓库；业务镜像推送到 Harbor。

---

## 问题 20: 从 containerd 导出镜像到 Docker

**场景**: 镜像已导入 containerd，需要推送到 Harbor，但 Harbor 只能通过 Docker 推送

**步骤**:
```bash
# 1. 从 containerd 导出
ctr -n k8s.io images export /tmp/image.tar <image>:<tag>

# 2. 导入到 Docker
docker load < /tmp/image.tar

# 3. 重新 tag
docker tag <image>:<tag> <harbor>/<project>/<image>:<tag>

# 4. 推送到 Harbor
docker push <harbor>/<project>/<image>:<tag>
```

**示例**:
```bash
# Kaniko 镜像推送到 Harbor
ctr -n k8s.io images export /tmp/kaniko.tar gcr.io/kaniko-project/executor:latest
docker load < /tmp/kaniko.tar
docker tag gcr.io/kaniko-project/executor:latest 182.42.82.135:30002/service-test/kaniko:latest
docker push 182.42.82.135:30002/service-test/kaniko:latest
```

---

## 当前 Tekton Pipeline 状态总结

### 已完成
- ✅ Tekton 安装 (Controller, Webhook, Resolvers)
- ✅ Pipeline 资源创建 (git-clone, build-push, service-test-pipeline)
- ✅ 镜像预导入到所有节点
- ✅ git-clone Task 执行成功
- ✅ Kaniko 镜像推送到 Harbor

### 当前卡点
- ❌ build-push Task 失败
- 原因: Tekton 控制器访问镜像仓库时 HTTPS/HTTP 不匹配

### 解决方向
1. 使用公共镜像仓库的 Kaniko 镜像 (推荐)
2. 为 Harbor 配置 HTTPS
3. 配置 Tekton 信任 HTTP 仓库

### Pipeline 执行流程
```
PipelineRun
│
├── ✅ git-clone Task
│   └── 从 Gitee 拉取代码成功
│
└── ❌ build-push Task (x4)
    └── Tekton 控制器访问镜像仓库失败
```


---

## 问题 21: Tekton 访问镜像仓库验证镜像信息导致超时

**现象**: TaskRun 显示 `PodCreationFailed`，错误信息包含访问镜像仓库超时
```
failed to create task run pod "xxx": translating TaskSpec to Pod: 
Get "https://xxx/v2/": dial tcp xxx:443: i/o timeout
```

**原因**: Tekton 控制器在创建 Pod 前会访问镜像仓库获取镜像的 entrypoint/command 信息

**解决方案**: 在 Task 的 step 中显式指定 `command`，避免 Tekton 访问仓库

```yaml
# 错误写法 - Tekton 需要访问仓库获取 entrypoint
steps:
- name: build
  image: 182.42.82.135:30002/service-test/kaniko:latest
  args:
  - --dockerfile=...

# 正确写法 - 显式指定 command
steps:
- name: build
  image: 182.42.82.135:30002/service-test/kaniko:latest
  command:           # 显式指定 command，避免访问仓库
  - /kaniko/executor
  args:
  - --dockerfile=...
```

**常见镜像的 command**:
| 镜像 | command |
|------|---------|
| kaniko | `/kaniko/executor` |
| alpine/git | `/bin/sh` |
| busybox | `/bin/sh` |

---

## 问题 22: emptyDir Workspace 数据不共享

**现象**: Clone Task 成功，但 Build Task 找不到代码文件
```
Error: error resolving dockerfile path: please provide a valid path to a Dockerfile
```

**原因**: 
- 使用 `emptyDir` 作为 workspace 时，每个 TaskRun 的 Pod 是独立的
- Clone Pod 的 emptyDir 数据不会传递给 Build Pod
- emptyDir 只在同一个 Pod 的生命周期内有效

**Tekton Workspace 数据共享机制**:
```
Pipeline
├── Task A (Pod 1)
│   └── emptyDir: /workspace  ← 数据在这里
│
└── Task B (Pod 2)
    └── emptyDir: /workspace  ← 这是新的空目录，看不到 Task A 的数据
```

**解决方案**:

方案 1 - 使用 PVC (推荐生产环境):
```yaml
workspaces:
- name: shared-workspace
  volumeClaimTemplate:
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 1Gi
```

方案 2 - 合并 Task (简单场景):
```yaml
# 把 clone 和 build 放在同一个 Task 的不同 steps 里
# 同一个 Pod 内的 steps 共享文件系统
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: clone-and-build
spec:
  steps:
  - name: clone
    image: alpine/git
    command: ["/bin/sh"]
    args: ["-c", "git clone $(params.git-url) /workspace/source"]
  - name: build
    image: kaniko
    command: ["/kaniko/executor"]
    args: ["--context=/workspace/source", ...]
```

**方案对比**:
| 方案 | 优点 | 缺点 |
|------|------|------|
| PVC | 数据持久化，可跨 Task 共享 | 需要 StorageClass |
| 合并 Task | 简单，无需额外配置 | 每个服务都要 clone 一次 |
| emptyDir | 最简单 | 只能在同一 Pod 内共享 |

---

## 问题总结表

| 问题编号 | 问题描述 | 解决方案 |
|----------|----------|----------|
| 1 | ArgoCD 镜像拉取 403 | 换用 quay.io 镜像 |
| 2 | ArgoCD 登录失败 | htpasswd 生成正确格式密码 |
| 6 | Tekton gcr.io 需要认证 | 本地拉取上传服务器 |
| 7 | Docker 推送 Harbor HTTPS 问题 | 配置 insecure-registries |
| 10 | PipelineRun API 版本错误 | taskRunTemplate.serviceAccountName |
| 11 | PodSecurity 限制 | namespace 设置 privileged |
| 12 | PVC 无法绑定 | 使用 emptyDir 或配置 StorageClass |
| 13 | Mac/服务器架构不匹配 | docker pull --platform linux/amd64 |
| 14 | containerd 镜像 digest 不匹配 | ctr images tag 创建别名 |
| 15 | 镜像只在部分节点 | 所有节点导入镜像 |
| 19 | Tekton 访问 Harbor HTTPS/HTTP | 使用公共镜像或配置 HTTPS |
| 21 | Tekton 访问仓库验证镜像 | 显式指定 command |
| 22 | emptyDir 数据不共享 | 使用 PVC 或合并 Task |


---

## 问题 17: Tekton Pipeline 中 Task 之间数据不共享

**现象**:
```
Error: error resolving dockerfile path: please provide a valid path to a Dockerfile within the build context with --dockerfile
```

Clone Task 成功，但 Build Task 找不到代码文件。

**排查过程**:

1. 检查 Clone Task 日志 - 确认代码拉取成功：
```bash
kubectl logs <clone-pod> -n tekton-pipelines -c step-clone
# 输出显示 git clone 成功，代码在 /workspace/output
```

2. 检查 Build Task 日志 - 发现 Dockerfile 路径不存在：
```bash
kubectl logs <build-pod> -n tekton-pipelines -c step-build-and-push
# 错误：error resolving dockerfile path
```

3. 检查 Pod 详情 - 确认 workspace 挂载正确：
```bash
kubectl get pod <build-pod> -o yaml | grep -A20 "volumeMounts"
# 显示 /workspace/source 已挂载
```

**根本原因**:
- Pipeline 使用 `emptyDir` 作为 workspace
- `emptyDir` 是 Pod 级别的临时存储
- Clone Task 和 Build Task 是**不同的 Pod**
- 数据无法在不同 Pod 之间共享

```
Clone Pod (emptyDir A)          Build Pod (emptyDir B)
├── /workspace/output/          ├── /workspace/source/
│   └── 代码文件 ✅              │   └── 空目录 ❌
```

**解决方案**:

方案 1 - 使用 PVC (推荐)：
```yaml
# PipelineRun 中使用 PVC
workspaces:
- name: shared-workspace
  persistentVolumeClaim:
    claimName: tekton-workspace-pvc
```

需要先创建 PVC：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tekton-workspace-pvc
  namespace: tekton-pipelines
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path  # 需要有 StorageClass
```

方案 2 - 使用 volumeClaimTemplate (动态创建 PVC)：
```yaml
workspaces:
- name: shared-workspace
  volumeClaimTemplate:
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: local-path
```

方案 3 - 合并 Task (不推荐，但可快速验证)：
将 clone 和 build 合并到一个 Task 中，这样在同一个 Pod 内执行。

**验证数据共享**:
```bash
# 检查 PVC 是否绑定
kubectl get pvc -n tekton-pipelines

# 检查 Pod 使用的 volume 类型
kubectl get pod <pod-name> -o yaml | grep -A5 "volumes:"
```

---

## 问题 18: Kaniko 镜像无法拉取 (gcr.io 超时)

**现象**:
```
failed to create task run pod: Get "https://gcr.io/v2/": dial tcp 74.125.20.82:443: i/o timeout
```

**原因**: 国内服务器无法访问 gcr.io

**解决方案**: 本地拉取后上传到服务器

```bash
# 1. 本地设置代理拉取
export https_proxy=http://127.0.0.1:7890
docker pull --platform linux/amd64 gcr.io/kaniko-project/executor:latest

# 2. 保存并压缩
docker save gcr.io/kaniko-project/executor:latest | gzip > /tmp/kaniko.tar.gz

# 3. 上传到所有 Worker 节点
for node in 182.42.80.121 182.42.95.71; do
  scp /tmp/kaniko.tar.gz root@$node:/tmp/
  ssh root@$node 'gunzip -c /tmp/kaniko.tar.gz | ctr -n k8s.io images import --all-platforms -'
done

# 4. 验证
ssh root@<node> 'ctr -n k8s.io images ls | grep kaniko'
```

**或者推送到 Harbor**:
```bash
# 修改 Task 使用 Harbor 镜像
image: 182.42.82.135:30002/service-test/kaniko:latest
```

---

## Tekton Pipeline 调试技巧

### 1. 查看 Pipeline 执行状态
```bash
# 查看 PipelineRun 状态
kubectl get pipelineruns -n tekton-pipelines

# 查看 TaskRun 状态
kubectl get taskruns -n tekton-pipelines

# 查看详细信息
kubectl describe pipelinerun <name> -n tekton-pipelines
```

### 2. 查看 Task 日志
```bash
# 列出 Pod 中的容器
kubectl get pod <pod-name> -n tekton-pipelines -o jsonpath='{.spec.containers[*].name}'

# 查看特定 step 的日志
kubectl logs <pod-name> -n tekton-pipelines -c step-<step-name>

# 查看所有容器日志
kubectl logs <pod-name> -n tekton-pipelines --all-containers
```

### 3. 检查 workspace 挂载
```bash
# 查看 Pod 的 volume 配置
kubectl get pod <pod-name> -o yaml | grep -A10 "volumes:"

# 查看 volumeMounts
kubectl get pod <pod-name> -o yaml | grep -A5 "volumeMounts:"
```

### 4. 检查参数替换
```bash
# 查看实际执行的命令参数
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[?(@.name=="step-xxx")].args}'
```

### 5. 进入 Pod 调试 (如果 Pod 还在运行)
```bash
kubectl exec -it <pod-name> -n tekton-pipelines -c step-<step-name> -- /bin/sh
```


---

## 问题 23: K8s Worker 节点 NotReady 导致 Harbor 服务不可用

**现象**:
- Harbor 返回 502 Bad Gateway
- Tekton TaskRun 显示 `TaskRunImagePullFailed`
- `kubectl get nodes` 显示某个 Worker 节点 NotReady

**排查步骤**:
```bash
# 1. 检查节点状态
kubectl get nodes

# 2. 查看节点详情
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# 3. 检查 Harbor Pod 状态
kubectl get pods -n devops

# 4. 查看 Harbor 组件日志
kubectl logs <harbor-core-pod> -n devops --tail=30
```

**根本原因**:
- Worker 节点的 kubelet 停止心跳，节点变为 NotReady
- 运行在该节点上的 Harbor Redis 和 Database Pod 处于 Terminating 状态
- Harbor Core 和 JobService 无法连接 Redis，进入 CrashLoopBackOff
- 整个 Harbor 服务不可用

**解决方案**:

方案 1 - 恢复节点:
```bash
# SSH 到故障节点重启 kubelet
ssh root@<node-ip> 'systemctl restart kubelet'

# 等待节点恢复
kubectl get nodes -w
```

方案 2 - 强制删除 Terminating Pod (节点无法恢复时):
```bash
kubectl delete pod <pod-name> -n devops --force --grace-period=0
```

方案 3 - 重启 CrashLoopBackOff 的 Pod:
```bash
# 节点恢复后，删除 CrashLoopBackOff 的 Pod 让其重建
kubectl delete pod <harbor-core-pod> <harbor-jobservice-pod> -n devops
```

**验证**:
```bash
# 检查 Harbor 健康状态
curl -s -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/health
```

---

## 问题 24: Harbor 项目丢失导致镜像拉取 401 Unauthorized

**现象**:
```
failed to pull and unpack image "182.42.82.135:30002/service-test/kaniko:latest": 
unexpected status from HEAD request: 401 Unauthorized
```

**原因**: Harbor 数据库重建后，之前创建的项目丢失

**排查步骤**:
```bash
# 检查 Harbor 项目列表
curl -s -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/projects | python3 -m json.tool
```

**解决方案**:
```bash
# 1. 重新创建项目
curl -X POST -u admin:Harbor12345 \
  -H "Content-Type: application/json" \
  http://182.42.82.135:30002/api/v2.0/projects \
  -d '{"project_name": "service-test", "public": true}'

# 2. 重新推送镜像
docker push 182.42.82.135:30002/service-test/kaniko:latest
```

---

## 问题 25: Kaniko 构建时无法拉取 Docker Hub 基础镜像

**现象**:
```
error building image: unable to complete operation after 0 attempts, last error: 
Get "https://index.docker.io/v2/": dial tcp 168.143.162.42:443: i/o timeout
```

**原因**: 国内服务器无法访问 Docker Hub (index.docker.io)

**解决方案**:

方案 1 - 预导入基础镜像到 Harbor:
```bash
# 1. 使用 DaoCloud 镜像加速拉取
docker pull docker.m.daocloud.io/library/golang:1.24-alpine
docker pull docker.m.daocloud.io/library/alpine:latest

# 2. 推送到 Harbor
docker tag docker.m.daocloud.io/library/golang:1.24-alpine 182.42.82.135:30002/library/golang:1.24-alpine
docker push 182.42.82.135:30002/library/golang:1.24-alpine

docker tag docker.m.daocloud.io/library/alpine:latest 182.42.82.135:30002/library/alpine:latest
docker push 182.42.82.135:30002/library/alpine:latest
```

方案 2 - 配置 Kaniko 使用 Harbor 作为镜像代理:
```yaml
# 在 Task 中添加 --registry-mirror 参数
args:
- --registry-mirror=182.42.82.135:30002
- --insecure-pull
```

**注意**: 需要确保 Harbor 中有对应的 `library/golang` 和 `library/alpine` 镜像

---

## 问题 26: Tekton TaskRun 超时 (TaskRunTimeout)

**现象**:
```
NAME                    SUCCEEDED   REASON           STARTTIME   COMPLETIONTIME
build-user-xxx          False       TaskRunTimeout   70m         10m
```

**原因**: Go 编译耗时较长，超过了默认的 1 小时超时时间

**解决方案**:

方案 1 - 在 Task 中设置 step 超时:
```yaml
steps:
- name: build-and-push
  image: kaniko
  timeout: 2h  # 设置 step 超时
  args: [...]
```

方案 2 - 在 PipelineRun 中设置全局超时:
```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
spec:
  timeouts:
    pipeline: 3h  # Pipeline 总超时
    tasks: 2h     # 单个 Task 超时
```

方案 3 - 优化 Kaniko 构建速度:
```yaml
args:
- --single-snapshot   # 减少快照次数
- --use-new-run       # 使用新的运行模式
- --cache=false       # 禁用缓存（如果缓存有问题）
```

---

## 问题 27: Harbor 返回 502 Bad Gateway 导致 Kaniko 构建失败

**现象**:
```
error building image: failed to get filesystem from image: 
GET http://182.42.82.135:30002/v2/library/alpine/blobs/sha256:xxx: 
unexpected status code 502 Bad Gateway
```

**原因**: Harbor 服务短暂不可用（可能是 Pod 重启、资源不足等）

**排查步骤**:
```bash
# 1. 检查 Harbor Pod 状态
kubectl get pods -n devops

# 2. 检查 Harbor 健康状态
curl -s -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/health

# 3. 查看 Harbor Core 日志
kubectl logs -n devops -l app=harbor -l component=core --tail=50
```

**解决方案**:
```bash
# 1. 等待 Harbor 恢复后重新运行 TaskRun
kubectl delete taskrun <failed-taskrun> -n tekton-pipelines

# 2. 重新触发构建
kubectl create -f pipelinerun-v2.yaml
```

---

## 2025-12-31 CI Pipeline 完成总结

### 遇到的问题链

```
1. worker2 节点 NotReady
   └── 2. Harbor Redis/Database Terminating
       └── 3. Harbor Core CrashLoopBackOff
           └── 4. Tekton 拉取镜像 502 Bad Gateway
               └── 5. TaskRun ImagePullFailed
```

### 解决过程

1. **节点恢复**: 等待/重启 worker2 节点的 kubelet
2. **Pod 重建**: 删除 CrashLoopBackOff 的 Harbor Pod
3. **项目重建**: 重新创建 Harbor 的 service-test 项目
4. **镜像推送**: 重新推送 kaniko 镜像到 Harbor
5. **基础镜像**: 预导入 golang 和 alpine 到 Harbor
6. **镜像代理**: 配置 Kaniko 使用 Harbor 作为 registry-mirror
7. **超时调整**: 增加 Task 超时到 2h

### 最终配置

**build-service-v2 Task 关键配置**:
```yaml
steps:
- name: build-and-push
  image: 182.42.82.135:30002/service-test/kaniko:latest
  command: ["/kaniko/executor"]
  args:
  - --dockerfile=/workspace/source/$(params.dockerfile)
  - --context=/workspace/source
  - --destination=$(params.image):$(params.tag)
  - --insecure
  - --skip-tls-verify
  - --cache=false
  - --registry-mirror=182.42.82.135:30002  # Harbor 作为镜像代理
  - --insecure-pull
  - --single-snapshot   # 优化构建速度
  - --use-new-run
  timeout: 2h  # 增加超时时间
```

### 构建成果

| 镜像 | 状态 |
|------|------|
| service-test/user-service:v1 | ✅ |
| service-test/product-service:v1 | ✅ |
| service-test/trade-service:v1 | ✅ |
| service-test/web-service:v1 | ✅ |
