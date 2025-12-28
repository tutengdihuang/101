# Jenkins + Harbor CI/CD 用户指南

本指南详细介绍如何在 Kubernetes 集群中搭建 Jenkins + Harbor CI/CD 流水线，实现代码推送自动构建、镜像推送和应用部署。

## 目录

1. [架构概述](#1-架构概述)
2. [环境准备](#2-环境准备)
3. [Harbor 部署](#3-harbor-部署)
4. [Jenkins 部署](#4-jenkins-部署)
5. [Webhook 配置](#5-webhook-配置)
6. [Pipeline 编写](#6-pipeline-编写)
7. [完整流程演示](#7-完整流程演示)
8. [排错指南](#8-排错指南)
9. [最佳实践](#9-最佳实践)

---

## 1. 架构概述

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              开发者工作流                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │ 本地开发  │───▶│ Git Push │───▶│  GitHub  │───▶│ Webhook 触发     │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           smee.io (Webhook 代理)                         │
│                    解决内网 Jenkins 无法被 GitHub 访问的问题               │
└─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            K8s 集群 (3 节点)                             │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │  Master 节点 (<MASTER_IP>)                                        ││
│  │  ├── Docker Engine (用于构建镜像)                                    ││
│  │  ├── smee-client (接收 Webhook)                                     ││
│  │  └── kubectl (集群管理)                                              ││
│  └────────────────────────────────────────────────────────────────────┘│
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │  devops namespace                                                   ││
│  │  ├── Jenkins (StatefulSet) ─── 挂载 Docker Socket                   ││
│  │  └── Harbor (Helm 部署) ─── core/portal/registry/db/redis           ││
│  └────────────────────────────────────────────────────────────────────┘│
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │  service-test namespace (业务服务)                                   ││
│  │  └── user-service / product-service / trade-service / web-service  ││
│  └────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```


### 1.2 CI/CD 流程

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│ Git Push│───▶│ Webhook │───▶│ Jenkins │───▶│ Docker  │───▶│ Harbor  │───▶│   K8s   │
│         │    │ 触发    │    │ 构建    │    │ Build   │    │ Push    │    │ Deploy  │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
```

**流程说明**：

1. **Git Push**: 开发者推送代码到 GitHub
2. **Webhook 触发**: GitHub 发送 webhook 到 smee.io，smee-client 转发到 Jenkins
3. **Jenkins 构建**: Jenkins 拉取代码，执行 Pipeline
4. **Docker Build**: 在 Master 节点构建 Docker 镜像
5. **Harbor Push**: 推送镜像到私有 Harbor 仓库
6. **K8s Deploy**: 使用 kubectl 更新 Deployment 镜像

### 1.3 组件说明

| 组件 | 作用 | 部署位置 |
|------|------|----------|
| **Jenkins** | CI/CD 引擎，执行 Pipeline | K8s devops namespace |
| **Harbor** | 私有镜像仓库 | K8s devops namespace |
| **Docker** | 构建镜像 | Master 节点 |
| **smee-client** | Webhook 代理 | Master 节点 |
| **kubectl** | K8s 部署 | Jenkins Pod 内 |

### 1.4 为什么选择这个架构？

**Jenkins + Harbor 的优势**：
- 完全自主可控，不依赖外部服务
- 适合企业内网环境
- Harbor 提供镜像漏洞扫描、签名等企业级功能
- Jenkins 插件生态丰富，支持复杂流水线

**为什么需要 smee.io？**
- Jenkins 部署在内网，GitHub 无法直接访问
- smee.io 作为公网代理，转发 webhook 到内网

---

## 2. 环境准备

### 2.1 集群要求

| 要求 | 说明 |
|------|------|
| K8s 版本 | 1.24+ |
| 节点数量 | 至少 1 个 Master + 1 个 Worker |
| 存储 | Master 节点需要本地存储 (hostPath) |
| 网络 | 能访问外网（拉取镜像、访问 GitHub） |

### 2.2 本指南使用的环境

| 节点 | IP | 角色 |
|------|-----|------|
| k8s-master | <MASTER_IP> | Master + Jenkins + Docker |
| k8s-worker1 | <WORKER1_IP> | Worker |
| k8s-worker2 | <WORKER2_IP> | Worker |

### 2.3 前置准备

#### 2.3.1 创建命名空间

```bash
kubectl create namespace devops
```

#### 2.3.2 在 Master 节点安装 Docker

K8s 1.24+ 默认使用 containerd，但 Jenkins 构建镜像需要 Docker：

```bash
# 在 Master 节点执行
apt-get update && apt-get install -y docker.io
systemctl enable docker && systemctl start docker
```

#### 2.3.3 配置 Docker 镜像加速（国内必须）

```bash
cat > /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["<MASTER_IP>:30002"],
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://registry.docker-cn.com"
  ]
}
EOF
systemctl restart docker
```

#### 2.3.4 创建 Jenkins 数据目录

```bash
# 在 Master 节点执行
mkdir -p /data/jenkins && chmod 777 /data/jenkins
```


---

## 3. Harbor 部署

Harbor 是企业级私有镜像仓库，提供镜像存储、漏洞扫描、访问控制等功能。

### 3.1 安装 Helm

```bash
wget https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz -O /tmp/helm.tar.gz
tar -zxvf /tmp/helm.tar.gz -C /tmp
mv /tmp/linux-amd64/helm /usr/local/bin/
helm version
```

### 3.2 添加 Harbor Helm 仓库

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

### 3.3 创建 Harbor values 文件

创建 `harbor-values.yaml`，关键配置：

```yaml
expose:
  type: nodePort
  nodePort:
    ports:
      http:
        nodePort: 30002    # Harbor 访问端口

externalURL: http://<MASTER_IP>:30002

harborAdminPassword: "<HARBOR_PASSWORD>"

# 使用 DaoCloud 镜像源（国内加速）
core:
  image:
    repository: docker.m.daocloud.io/goharbor/harbor-core
portal:
  image:
    repository: docker.m.daocloud.io/goharbor/harbor-portal
# ... 其他组件类似
```

### 3.4 安装 Harbor

```bash
helm upgrade --install harbor harbor/harbor \
  -n devops \
  -f harbor-values.yaml \
  --timeout 10m
```

### 3.5 验证 Harbor

```bash
# 检查 Pod 状态
kubectl get pods -n devops -l app=harbor

# 测试 API
curl -u admin:<HARBOR_PASSWORD> http://<MASTER_IP>:30002/api/v2.0/health
```

### 3.6 创建项目

```bash
curl -u admin:<HARBOR_PASSWORD> -X POST 'http://<MASTER_IP>:30002/api/v2.0/projects' \
  -H 'Content-Type: application/json' \
  -d '{"project_name": "service-test", "public": true}'
```

### 3.7 配置节点信任 Harbor

Harbor 使用 HTTP（非 HTTPS），需要配置所有节点信任：

**Docker 配置**（Master 节点）：
```bash
# /etc/docker/daemon.json 添加
{"insecure-registries":["<MASTER_IP>:30002"]}
systemctl restart docker
```

**containerd 配置**（所有节点）：
```bash
cat >> /etc/containerd/config.toml << 'EOF'
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."<MASTER_IP>:30002"]
  endpoint = ["http://<MASTER_IP>:30002"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."<MASTER_IP>:30002".tls]
  insecure_skip_verify = true
EOF
systemctl restart containerd
```

---

## 4. Jenkins 部署

### 4.1 部署架构

Jenkins 以 StatefulSet 方式部署，关键设计：
- 使用 `nodeSelector` 固定在 Master 节点
- 挂载 Docker Socket 实现镜像构建
- 使用 hostPath 持久化数据

### 4.2 创建 RBAC

Jenkins 需要权限操作 K8s 资源：

```yaml
# jenkins-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: devops
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: devops
```

```bash
kubectl apply -f jenkins-rbac.yaml
```


### 4.3 创建 PV/PVC

```yaml
# jenkins-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/jenkins
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-master
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: devops
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### 4.4 部署 Jenkins StatefulSet

```yaml
# jenkins-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jenkins
  namespace: devops
spec:
  serviceName: jenkins
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      nodeSelector:
        kubernetes.io/hostname: k8s-master  # 固定在 Master 节点
      containers:
      - name: jenkins
        image: docker.m.daocloud.io/jenkins/jenkins:lts-jdk17
        ports:
        - containerPort: 8080
        - containerPort: 50000
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: docker-bin
          mountPath: /usr/bin/docker
        securityContext:
          runAsUser: 0  # 以 root 运行，访问 Docker Socket
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-pvc
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
          type: Socket
      - name: docker-bin
        hostPath:
          path: /usr/bin/docker
          type: File
```

### 4.5 创建 Service

```yaml
# jenkins-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: devops
spec:
  type: NodePort
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30080
  - name: agent
    port: 50000
    targetPort: 50000
  selector:
    app: jenkins
```

### 4.6 部署并获取初始密码

```bash
kubectl apply -f jenkins-rbac.yaml
kubectl apply -f jenkins-pvc.yaml
kubectl apply -f jenkins-deployment.yaml
kubectl apply -f jenkins-service.yaml

# 等待 Pod 就绪
kubectl get pods -n devops -w

# 获取初始密码
kubectl exec jenkins-0 -n devops -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### 4.7 初始化 Jenkins

1. 访问 http://<MASTER_IP>:30080
2. 输入初始密码
3. 选择 "Install suggested plugins"
4. 创建管理员账号

### 4.8 安装必要插件

进入 Manage Jenkins → Plugins → Available plugins，安装：
- Docker Pipeline
- Git
- Pipeline
- GitHub

### 4.9 配置 Harbor 凭证

1. Manage Jenkins → Credentials → System → Global credentials
2. Add Credentials:
   - Kind: Username with password
   - Username: `admin`
   - Password: `<HARBOR_PASSWORD>`
   - ID: `harbor-credentials`

### 4.10 在 Jenkins Pod 中安装 kubectl

```bash
kubectl exec jenkins-0 -n devops -- bash -c '
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl" && \
chmod +x kubectl && \
mv kubectl /usr/local/bin/
'
```

### 4.11 配置 kubeconfig

```bash
# 创建目录
kubectl exec jenkins-0 -n devops -- mkdir -p /var/jenkins_home/.kube

# 复制 kubeconfig
kubectl cp /root/.kube/config devops/jenkins-0:/var/jenkins_home/.kube/config

# 修改 server 地址为 IP（如果使用主机名）
kubectl exec jenkins-0 -n devops -- sed -i 's|https://k8s-master-internal:6443|https://<MASTER_IP>:6443|g' /var/jenkins_home/.kube/config

# 验证
kubectl exec jenkins-0 -n devops -- kubectl --kubeconfig=/var/jenkins_home/.kube/config get nodes
```


---

## 5. Webhook 配置

由于 Jenkins 部署在内网，GitHub 无法直接访问，需要使用 smee.io 作为 Webhook 代理。

### 5.1 架构说明

```
GitHub ──▶ smee.io (公网) ──▶ smee-client (Master节点) ──▶ Jenkins (内网)
```

### 5.2 获取 smee.io 通道

1. 访问 https://smee.io/new
2. 复制生成的 URL，如：`https://smee.io/<YOUR_SMEE_CHANNEL>`

### 5.3 安装 smee-client

**方式一：使用 pysmee（推荐，兼容性好）**

```bash
pip3 install pysmee
```

**方式二：使用 Node.js smee-client（需要 Node.js 20+）**

```bash
npm install -g smee-client
```

### 5.4 运行 smee-client

```bash
# 使用 pysmee
nohup pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/ > /var/log/smee.log 2>&1 &

# 或使用 Node.js 版本
nohup smee -u https://smee.io/YOUR_CHANNEL -t http://localhost:30080/github-webhook/ > /var/log/smee.log 2>&1 &
```

### 5.5 配置 GitHub Webhook

1. 进入 GitHub 仓库 → Settings → Webhooks → Add webhook
2. 配置：
   - Payload URL: `https://smee.io/YOUR_CHANNEL`
   - Content type: `application/json`
   - Events: `Just the push event`
3. 点击 Add webhook

### 5.6 验证 Webhook

推送代码后，检查：
1. smee.io 页面是否收到请求
2. Jenkins 是否触发构建

```bash
# 查看 smee 日志
tail -f /var/log/smee.log

# 查看 Jenkins 构建
kubectl exec jenkins-0 -n devops -- ls /var/jenkins_home/jobs/YOUR_JOB/builds/
```

### 5.7 设置 smee-client 开机自启（可选）

创建 systemd 服务：

```bash
cat > /etc/systemd/system/smee.service << 'EOF'
[Unit]
Description=Smee Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable smee
systemctl start smee
```

---

## 6. Pipeline 编写

### 6.1 Jenkinsfile 结构

```groovy
pipeline {
    agent any                    // 在任意节点执行
    
    triggers {
        githubPush()             // GitHub Webhook 触发
    }
    
    environment {
        // 环境变量
    }
    
    stages {
        stage('Checkout') { }    // 拉取代码
        stage('Build') { }       // 构建镜像
        stage('Push') { }        // 推送镜像
        stage('Deploy') { }      // 部署到 K8s
        stage('Verify') { }      // 验证部署
    }
    
    post {
        success { }              // 成功后操作
        failure { }              // 失败后操作
        always { }               // 总是执行
    }
}
```

### 6.2 完整 Jenkinsfile 示例

```groovy
// Jenkins Pipeline for go-zero microservices
pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        // Harbor 配置
        HARBOR_URL = '<MASTER_IP>:30002'
        HARBOR_PROJECT = 'service-test'
        HARBOR_CREDENTIALS = 'harbor-credentials'
        
        // K8s 配置
        K8S_NAMESPACE = 'service-test'
        KUBECONFIG = '/var/jenkins_home/.kube/config'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "=== 拉取代码 ==="
                checkout scm
                sh 'git log -1 --oneline'
            }
        }
        
        stage('Build & Push Images') {
            steps {
                script {
                    def services = [
                        [name: 'user', dockerfile: 'dockerfiles/Dockerfile.user'],
                        [name: 'product', dockerfile: 'dockerfiles/Dockerfile.product'],
                        [name: 'trade', dockerfile: 'dockerfiles/Dockerfile.trade'],
                        [name: 'web', dockerfile: 'dockerfiles/Dockerfile.web']
                    ]
                    
                    // 登录 Harbor
                    withCredentials([usernamePassword(
                        credentialsId: env.HARBOR_CREDENTIALS,
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASS'
                    )]) {
                        sh "docker login -u ${HARBOR_USER} -p ${HARBOR_PASS} ${HARBOR_URL}"
                    }
                    
                    // 构建并推送每个服务
                    services.each { svc ->
                        def imageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${svc.name}-service"
                        def imageTag = "${env.BUILD_NUMBER}"
                        
                        echo "=== 构建 ${svc.name} 服务 ==="
                        sh "docker build -f ${svc.dockerfile} -t ${imageName}:${imageTag} -t ${imageName}:latest ."
                        
                        echo "=== 推送 ${svc.name} 镜像 ==="
                        sh "docker push ${imageName}:${imageTag}"
                        sh "docker push ${imageName}:latest"
                        
                        // 清理本地镜像
                        sh "docker rmi ${imageName}:${imageTag} || true"
                    }
                }
            }
        }
        
        stage('Deploy to K8s') {
            steps {
                script {
                    def services = [
                        [name: 'user', container: 'user'],
                        [name: 'product', container: 'product'],
                        [name: 'trade', container: 'trade'],
                        [name: 'web', container: 'web-service']
                    ]
                    
                    services.each { svc ->
                        def imageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${svc.name}-service"
                        def imageTag = "${env.BUILD_NUMBER}"
                        
                        echo "=== 部署 ${svc.name} 服务 ==="
                        sh "kubectl set image deployment/${svc.name}-service ${svc.container}=${imageName}:${imageTag} -n ${K8S_NAMESPACE}"
                    }
                }
            }
        }
        
        stage('Verify') {
            steps {
                echo "=== 验证部署 ==="
                sh "kubectl get pods -n ${K8S_NAMESPACE}"
            }
        }
    }
    
    post {
        success { echo '=== Pipeline 成功 ===' }
        failure { echo '=== Pipeline 失败 ===' }
        always { sh "docker logout ${HARBOR_URL} || true" }
    }
}
```


### 6.3 创建 Jenkins Job

**方式一：通过 UI 创建**

1. Jenkins 首页 → New Item
2. 输入名称，选择 "Pipeline"
3. 配置：
   - GitHub project: 填写仓库 URL
   - Build Triggers: 勾选 "GitHub hook trigger for GITScm polling"
   - Pipeline: 选择 "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: 填写仓库 URL
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

**方式二：通过 API 创建**

```bash
# 获取 CRUMB
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' \
  --user 'admin:<YOUR_API_TOKEN>' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)

# 创建 Job
curl -X POST 'http://localhost:30080/createItem?name=service-test' \
  --user 'admin:<YOUR_API_TOKEN>' \
  -H "Jenkins-Crumb: $CRUMB" \
  -H "Content-Type: application/xml" \
  --data-binary @job-config.xml
```

### 6.4 Dockerfile 最佳实践

```dockerfile
# 多阶段构建，减小镜像体积
FROM golang:1.24-alpine AS builder

WORKDIR /build

# 设置 Go 代理（国内加速）
ENV GOPROXY=https://goproxy.cn,direct

# 安装依赖
RUN apk add --no-cache git make ca-certificates tzdata

# 先复制依赖文件，利用缓存
COPY go.mod go.sum ./
RUN go mod download

# 复制源码并编译
COPY . .
WORKDIR /build/rpc/user
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o user .

# 最终镜像
FROM alpine:3.18

RUN apk --no-cache add ca-certificates tzdata
ENV TZ=Asia/Shanghai

WORKDIR /app
COPY --from=builder /build/rpc/user/user .
COPY --from=builder /build/rpc/user/etc ./etc

EXPOSE 9001
ENTRYPOINT ["./user"]
CMD ["-f", "etc/user.yaml"]
```

---

## 7. 完整流程演示

### 7.1 准备工作

确保以下组件正常运行：

```bash
# 检查 Jenkins
kubectl get pod jenkins-0 -n devops

# 检查 Harbor
curl -u admin:<HARBOR_PASSWORD> http://<MASTER_IP>:30002/api/v2.0/health

# 检查 smee-client
ps aux | grep smee
```

### 7.2 触发构建

**方式一：推送代码（自动触发）**

```bash
cd your-project
echo "// test $(date)" >> test.txt
git add test.txt
git commit -m "test: trigger CI/CD"
git push origin main
```

**方式二：手动触发**

```bash
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' \
  --user 'admin:<YOUR_API_TOKEN>' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)

curl -X POST 'http://localhost:30080/job/service-test/build' \
  --user 'admin:<YOUR_API_TOKEN>' \
  -H "Jenkins-Crumb: $CRUMB"
```

### 7.3 监控构建

```bash
# 查看构建列表
kubectl exec jenkins-0 -n devops -- ls /var/jenkins_home/jobs/service-test/builds/

# 查看构建日志
kubectl exec jenkins-0 -n devops -- cat /var/jenkins_home/jobs/service-test/builds/LATEST/log
```

### 7.4 验证结果

```bash
# 检查 Harbor 镜像
curl -s -u admin:<HARBOR_PASSWORD> 'http://<MASTER_IP>:30002/api/v2.0/projects/service-test/repositories' | python3 -m json.tool

# 检查 K8s 部署
kubectl get deployments -n service-test -o wide

# 检查 Pod 状态
kubectl get pods -n service-test
```

---

## 8. 排错指南

### 8.1 常见问题速查表

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| Jenkins 镜像拉取失败 | 国内网络无法访问 Docker Hub | 使用 DaoCloud 镜像源 |
| Harbor 镜像拉取失败 | 同上 | 配置 DaoCloud 镜像源 |
| Docker build 失败 | Docker 未安装或未启动 | 在 Master 节点安装 Docker |
| kubectl not found | Jenkins Pod 未安装 kubectl | 手动安装 kubectl |
| kubectl 连接失败 | kubeconfig 未配置或地址错误 | 复制并修改 kubeconfig |
| Webhook 未触发 | smee-client 未运行 | 重启 smee-client |
| GitHub 拉取超时 | 国内网络不稳定 | 重试或配置代理 |
| Harbor 推送失败 | 未配置 insecure-registries | 配置 Docker/containerd 信任 |

### 8.2 诊断命令

```bash
# 查看 Jenkins 日志
kubectl logs jenkins-0 -n devops --tail=100

# 查看构建日志
kubectl exec jenkins-0 -n devops -- cat /var/jenkins_home/jobs/service-test/builds/LATEST/log

# 检查 Docker 是否可用
kubectl exec jenkins-0 -n devops -- docker version

# 检查 Harbor 连接
kubectl exec jenkins-0 -n devops -- docker login <MASTER_IP>:30002 -u admin -p <HARBOR_PASSWORD>

# 检查 kubectl 是否可用
kubectl exec jenkins-0 -n devops -- kubectl --kubeconfig=/var/jenkins_home/.kube/config get nodes

# 检查 smee-client
ps aux | grep smee
cat /var/log/smee.log
```


### 8.3 详细问题排查

#### 问题 1：Jenkins Pod 无法启动

**现象**：Pod 状态为 `ImagePullBackOff` 或 `ErrImagePull`

**排查**：
```bash
kubectl describe pod jenkins-0 -n devops
```

**解决**：
使用国内镜像源：
```yaml
image: docker.m.daocloud.io/jenkins/jenkins:lts-jdk17
```

#### 问题 2：Docker Socket 挂载失败

**现象**：Pod 启动失败，报错 `not a socket file`

**排查**：
```bash
ls -la /var/run/docker.sock
```

**解决**：
确保 Master 节点已安装并启动 Docker：
```bash
apt-get install -y docker.io
systemctl start docker
```

#### 问题 3：kubectl 无法连接 API Server

**现象**：报错 `dial tcp: lookup k8s-master-internal: no such host`

**原因**：kubeconfig 中使用主机名，Jenkins Pod 无法解析

**解决**：
```bash
kubectl exec jenkins-0 -n devops -- sed -i 's|https://k8s-master-internal:6443|https://<MASTER_IP>:6443|g' /var/jenkins_home/.kube/config
```

#### 问题 4：Harbor 凭证错误

**现象**：报错 `CredentialNotFoundException: harbor-credentials`

**解决**：
在 Jenkins 中添加凭证：
1. Manage Jenkins → Credentials
2. Add Credentials (Username with password)
3. ID 必须是 `harbor-credentials`

#### 问题 5：K8s 无法拉取 Harbor 镜像

**现象**：Pod 状态为 `ImagePullBackOff`

**排查**：
```bash
kubectl describe pod <pod-name> -n service-test
```

**解决**：
配置所有节点的 containerd 信任 Harbor：
```bash
cat >> /etc/containerd/config.toml << 'EOF'
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."<MASTER_IP>:30002"]
  endpoint = ["http://<MASTER_IP>:30002"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."<MASTER_IP>:30002".tls]
  insecure_skip_verify = true
EOF
systemctl restart containerd
```

#### 问题 6：Webhook 未触发构建

**排查步骤**：

1. 检查 smee-client 是否运行：
```bash
ps aux | grep smee
```

2. 检查 smee 日志：
```bash
cat /var/log/smee.log
```

3. 检查 GitHub Webhook 配置：
   - Payload URL 是否正确
   - Content type 是否为 `application/json`

4. 检查 Jenkins Job 配置：
   - 是否勾选 "GitHub hook trigger for GITScm polling"

#### 问题 7：GitHub 网络超时

**现象**：
```
curl 28 Failed to connect to github.com port 443 after 130969 ms
```

**原因**：从中国访问 GitHub 网络不稳定

**解决方案**：
1. 重试构建
2. 配置 Git 代理
3. 使用 Gitee 镜像同步

---

## 9. 最佳实践

### 9.1 安全建议

1. **不要使用 cluster-admin**：为 Jenkins 创建最小权限的 Role
2. **使用 HTTPS**：为 Harbor 配置 TLS 证书
3. **定期轮换密码**：Jenkins API Token、Harbor 密码
4. **镜像扫描**：启用 Harbor 的漏洞扫描功能

### 9.2 性能优化

1. **Docker 层缓存**：合理组织 Dockerfile，利用构建缓存
2. **并行构建**：使用 Jenkins 的 parallel 语法并行构建多个服务
3. **镜像清理**：定期清理 Harbor 中的旧镜像

### 9.3 高可用建议

1. **Jenkins 备份**：定期备份 `/var/jenkins_home`
2. **Harbor 高可用**：使用外部数据库和 Redis
3. **smee-client 自启**：配置 systemd 服务

### 9.4 监控告警

1. **Jenkins 监控**：安装 Prometheus 插件
2. **Harbor 监控**：配置 Harbor 的 metrics 端点
3. **构建通知**：配置 Slack/钉钉通知

---

## 附录

### A. 文件清单

```
jenkins_harbor/
├── USER_GUIDE.md              # 本文档
├── README.md                  # 方案概述
├── SETUP_GUIDE.md             # 部署步骤
├── TROUBLESHOOTING.md         # 问题排查
├── jenkins/
│   ├── jenkins-rbac.yaml
│   ├── jenkins-pvc.yaml
│   ├── jenkins-deployment.yaml
│   └── jenkins-service.yaml
├── harbor/
│   └── harbor-values.yaml
└── project-files/
    └── Jenkinsfile
```

### B. 访问信息

| 服务 | 地址 | 账号 |
|------|------|------|
| Jenkins | http://<MASTER_IP>:30080 | admin / (初始密码) |
| Harbor | http://<MASTER_IP>:30002 | admin / <HARBOR_PASSWORD> |
| smee.io | https://smee.io/<YOUR_SMEE_CHANNEL> | - |

### C. 常用命令速查

```bash
# Jenkins
kubectl exec -it jenkins-0 -n devops -- bash
kubectl logs jenkins-0 -n devops

# Harbor
curl -u admin:<HARBOR_PASSWORD> http://<MASTER_IP>:30002/api/v2.0/projects

# 触发构建
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' --user 'admin:TOKEN' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)
curl -X POST 'http://localhost:30080/job/service-test/build' --user 'admin:TOKEN' -H "Jenkins-Crumb: $CRUMB"

# 查看部署
kubectl get deployments -n service-test -o wide
```
