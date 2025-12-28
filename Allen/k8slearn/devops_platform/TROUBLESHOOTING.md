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
