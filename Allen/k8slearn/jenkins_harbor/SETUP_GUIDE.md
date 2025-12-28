# Jenkins + Harbor 部署指南

## 一、环境信息

| 节点 | IP | 角色 |
|------|-----|------|
| k8s-master | 182.42.82.135 | Master + Jenkins + Docker |
| k8s-worker1 | 182.42.80.121 | Worker |
| k8s-worker2 | 182.42.95.71 | Worker |

SSH 密码: `Nihao321!`

## 二、架构说明

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

## 三、访问信息

| 服务 | 地址 | 账号 |
|------|------|------|
| **Jenkins** | http://182.42.82.135:30080 | admin / 见下方获取 |
| **Harbor** | http://182.42.82.135:30002 | admin / Harbor12345 |

### 获取 Jenkins 初始密码
```bash
kubectl exec -it jenkins-0 -n devops -- cat /var/jenkins_home/secrets/initialAdminPassword
# 输出: 8133ab68963d4ff38d78fee334c8b21a
```

## 四、部署步骤 (实际执行记录)

### 4.1 创建命名空间

```bash
kubectl create namespace devops
```

### 4.2 在 Master 节点创建数据目录

```bash
ssh root@182.42.82.135 "mkdir -p /data/jenkins && chmod 777 /data/jenkins"
```

### 4.3 部署 Jenkins RBAC

```bash
kubectl apply -f jenkins/jenkins-rbac.yaml
```

### 4.4 部署 Jenkins PVC

```bash
kubectl apply -f jenkins/jenkins-pvc.yaml
```

### 4.5 部署 Jenkins StatefulSet

```bash
kubectl apply -f jenkins/jenkins-deployment.yaml
```

### 4.6 部署 Jenkins Service

```bash
kubectl apply -f jenkins/jenkins-service.yaml
```

### 4.7 等待 Jenkins 就绪

```bash
kubectl get pods -n devops -w
# 等待 jenkins-0 变为 Running 状态
```

### 4.8 安装 Helm (Master 节点)

```bash
ssh root@182.42.82.135 "
wget https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz -O /tmp/helm.tar.gz
tar -zxvf /tmp/helm.tar.gz -C /tmp
mv /tmp/linux-amd64/helm /usr/local/bin/
helm version
"
```

### 4.9 安装 Harbor

```bash
ssh root@182.42.82.135 "
helm repo add harbor https://helm.goharbor.io
helm repo update
"

# 复制 values 文件并安装
scp harbor/harbor-values.yaml root@182.42.82.135:/tmp/
ssh root@182.42.82.135 "helm upgrade --install harbor harbor/harbor -n devops -f /tmp/harbor-values.yaml --timeout 10m"
```

### 4.10 在 Master 节点安装 Docker

```bash
ssh root@182.42.82.135 "apt-get update && apt-get install -y docker.io && systemctl enable docker && systemctl start docker"
```

### 4.11 配置 Docker 信任 Harbor

```bash
ssh root@182.42.82.135 "
mkdir -p /etc/docker
echo '{\"insecure-registries\":[\"182.42.82.135:30002\"]}' > /etc/docker/daemon.json
systemctl restart docker
"
```

### 4.12 配置所有节点 containerd 信任 Harbor

在每个节点执行:
```bash
cat >> /etc/containerd/config.toml << 'EOF'
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."182.42.82.135:30002"]
          endpoint = ["http://182.42.82.135:30002"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."182.42.82.135:30002".tls]
        insecure_skip_verify = true
EOF
systemctl restart containerd
```

### 4.13 创建 Harbor 项目

```bash
curl -u admin:Harbor12345 -X POST 'http://182.42.82.135:30002/api/v2.0/projects' \
  -H 'Content-Type: application/json' \
  -d '{"project_name": "service-test", "public": true}'
```

### 4.14 重新部署 Jenkins (挂载 Docker Socket)

```bash
kubectl delete statefulset jenkins -n devops
kubectl apply -f jenkins/jenkins-deployment.yaml
```

## 五、验证部署

### 5.1 查看 Pod 状态
```bash
kubectl get pods -n devops
```

预期输出:
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

### 5.2 验证 Jenkins 可以使用 Docker
```bash
kubectl exec jenkins-0 -n devops -- docker version
```

### 5.3 验证 Jenkins 可以登录 Harbor
```bash
kubectl exec jenkins-0 -n devops -- docker login 182.42.82.135:30002 -u admin -p Harbor12345
# 输出: Login Succeeded
```

### 5.4 验证 Harbor API
```bash
curl -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/projects
```

## 六、遇到的问题及解决

### 6.1 Jenkins 镜像拉取失败

**问题**: `ImagePullBackOff` - 无法拉取 `jenkins/jenkins:lts-jdk17`

**原因**: 国内网络无法访问 Docker Hub

**解决**: 使用 DaoCloud 镜像源
```yaml
image: docker.m.daocloud.io/jenkins/jenkins:lts-jdk17
```

### 6.2 Harbor 镜像拉取失败

**问题**: Harbor 组件镜像无法拉取

**原因**: 国内网络无法访问 goharbor 镜像

**解决**: 在 `harbor-values.yaml` 中配置 DaoCloud 镜像源
```yaml
core:
  image:
    repository: docker.m.daocloud.io/goharbor/harbor-core
portal:
  image:
    repository: docker.m.daocloud.io/goharbor/harbor-portal
# ... 其他组件类似
```

### 6.3 Master 节点没有 Docker

**问题**: K8s 集群使用 containerd 作为容器运行时，Master 节点没有 Docker

**原因**: 现代 K8s 集群默认使用 containerd，不再依赖 Docker

**解决**: 在 Master 节点单独安装 Docker 用于构建镜像
```bash
apt-get install -y docker.io
```

### 6.4 Docker Socket 挂载失败

**问题**: Jenkins Pod 无法挂载 `/var/run/docker.sock`，报错 `not a socket file`

**原因**: Docker 未安装，socket 文件不存在

**解决**: 先安装 Docker，确保 socket 文件存在后再部署 Jenkins

### 6.5 K8s 无法拉取 Harbor 镜像

**问题**: 业务 Pod 无法从 Harbor 拉取镜像

**原因**: containerd 不信任 HTTP 协议的私有仓库

**解决**: 配置 containerd 信任 Harbor
```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."182.42.82.135:30002"]
  endpoint = ["http://182.42.82.135:30002"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."182.42.82.135:30002".tls]
  insecure_skip_verify = true
```

## 七、配置 Jenkins

### 7.1 访问 Jenkins

浏览器打开: http://182.42.82.135:30080

### 7.2 安装推荐插件

首次登录后选择 "Install suggested plugins"

### 7.3 安装额外插件

进入 "Manage Jenkins" -> "Plugins" -> "Available plugins"，安装：
- Docker Pipeline
- Kubernetes
- Git
- Pipeline

### 7.4 配置 Harbor 凭证

1. 进入 "Manage Jenkins" -> "Credentials"
2. 点击 "System" -> "Global credentials"
3. 点击 "Add Credentials"
4. 选择 "Username with password"
   - Username: `admin`
   - Password: `Harbor12345`
   - ID: `harbor-credentials`
   - Description: `Harbor Registry`

### 7.5 创建 Pipeline 项目

1. 点击 "New Item"
2. 输入名称: `service-test`
3. 选择 "Pipeline"
4. 在 Pipeline 配置中使用 `pipeline/Jenkinsfile`

## 八、目录结构

```
jenkins_harbor/
├── README.md                     # 方案概述
├── SETUP_GUIDE.md                # 本文档
├── deploy.sh                     # 一键部署脚本
├── namespace.yaml                # devops 命名空间
├── jenkins/
│   ├── jenkins-rbac.yaml         # RBAC 权限
│   ├── jenkins-pvc.yaml          # 持久化存储 (hostPath /data/jenkins)
│   ├── jenkins-deployment.yaml   # StatefulSet (DaoCloud镜像+Docker挂载)
│   └── jenkins-service.yaml      # NodePort 30080
├── harbor/
│   ├── harbor-values.yaml        # Helm values (DaoCloud镜像源)
│   └── harbor-install.sh         # 安装脚本
├── pipeline/
│   └── Jenkinsfile               # CI/CD 流水线
└── k8s-deployments/
    ├── user-deployment.yaml      # 使用 Harbor 镜像的部署配置
    ├── product-deployment.yaml
    ├── trade-deployment.yaml
    └── web-deployment.yaml
```

## 九、清理

```bash
# 删除 Jenkins
kubectl delete -f jenkins/

# 删除 Harbor
helm uninstall harbor -n devops

# 删除 PVC 和 PV
kubectl delete pvc jenkins-pvc -n devops
kubectl delete pv jenkins-pv

# 删除命名空间
kubectl delete namespace devops

# 清理 Master 节点数据
ssh root@182.42.82.135 "rm -rf /data/jenkins"
```

## 十、相关命令速查

```bash
# 查看 devops 命名空间 Pod
kubectl get pods -n devops

# 查看服务
kubectl get svc -n devops

# 查看 Jenkins 日志
kubectl logs -f jenkins-0 -n devops

# 进入 Jenkins Pod
kubectl exec -it jenkins-0 -n devops -- bash

# 查看 Harbor 组件
kubectl get pods -n devops -l app=harbor

# 测试 Harbor 连接
curl -u admin:Harbor12345 http://182.42.82.135:30002/api/v2.0/health
```
