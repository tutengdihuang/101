# Service Test CI/CD 到 Kubernetes

这个目录包含了将 service_test 项目部署到 Kubernetes 的完整 CI/CD 配置。

## 目录结构

```
Allen/k8slearn/
├── ci-cd.yml                    # GitHub Actions 工作流
├── dockerfiles/                  # Dockerfile 文件
│   ├── Dockerfile.web
│   ├── Dockerfile.user
│   ├── Dockerfile.product
│   └── Dockerfile.trade
├── k8s/                         # Kubernetes 部署文件
│   ├── namespace.yaml           # 命名空间
│   ├── configmap.yaml          # 配置映射（etcd 配置）
│   ├── web/
│   │   └── deployment.yaml      # Web 服务部署（HTTP API 网关）
│   ├── user/
│   │   └── deployment.yaml     # User RPC 服务部署
│   ├── product/
│   │   └── deployment.yaml     # Product RPC 服务部署
│   └── trade/
│       └── deployment.yaml      # Trade RPC 服务部署
└── README.md                    # 本文件
```

## 服务说明

### 服务架构

1. **web** - HTTP API 网关服务（端口 8888）
   - 提供对外 HTTP 接口
   - 依赖 user、product、trade 服务

2. **user** - 用户信息服务（RPC，端口 9001）
   - gRPC 服务

3. **product** - 产品信息服务（RPC，端口 9002）
   - gRPC 服务

4. **trade** - 交易服务（RPC，端口 9003）
   - gRPC 服务
   - 依赖 user 和 product 服务

## 使用步骤

### 1. 准备工作

#### 1.1 将文件复制到项目根目录

```bash
# 复制 CI/CD 工作流到项目
cp ci-cd.yml /Volumes/mac_data/code/go_code/service_test/.github/workflows/

# 复制 Dockerfile 到项目根目录
cp -r dockerfiles /Volumes/mac_data/code/go_code/service_test/

# 复制 Kubernetes 部署文件到项目根目录
cp -r k8s /Volumes/mac_data/code/go_code/service_test/
```

#### 1.2 配置 GitHub Secrets

在 GitHub 仓库的 Settings → Secrets and variables → Actions 中配置：

1. **KUBECONFIG** - Kubernetes 配置文件（base64 编码）
   ```bash
   cat ~/.kube/config | base64 -w 0
   ```

2. 如果使用其他镜像仓库，需要配置：
   - `REGISTRY_USERNAME` - 镜像仓库用户名
   - `REGISTRY_PASSWORD` - 镜像仓库密码或 token

#### 1.3 修改配置

1. **修改镜像仓库地址**（如果需要）
   - 编辑 `ci-cd.yml` 中的 `REGISTRY` 和 `IMAGE_PREFIX`

2. **修改 Kubernetes 部署文件中的镜像地址**
   - 编辑 `k8s/*/deployment.yaml` 中的镜像地址（CI/CD 会自动替换）

3. **修改 Ingress 域名**
   - 编辑 `k8s/web/deployment.yaml` 中的 Ingress host

### 2. CI/CD 流程

#### 2.1 自动触发

当代码推送到 `main`、`master` 或 `develop` 分支时，会自动触发：

1. **测试阶段**：代码检查、依赖下载、编译验证
2. **构建阶段**：并行构建 4 个服务的 Docker 镜像
3. **部署阶段**（仅 main/master）：自动部署到 Kubernetes

#### 2.2 手动触发

在 GitHub Actions 页面可以手动触发工作流，并选择构建特定服务或全部服务。

### 3. 本地测试

#### 3.1 构建 Docker 镜像

```bash
# 构建 web 服务镜像
docker build -f dockerfiles/Dockerfile.web -t service-test/web-service:latest .

# 构建 user 服务镜像
docker build -f dockerfiles/Dockerfile.user -t service-test/user-service:latest .

# 构建 product 服务镜像
docker build -f dockerfiles/Dockerfile.product -t service-test/product-service:latest .

# 构建 trade 服务镜像
docker build -f dockerfiles/Dockerfile.trade -t service-test/trade-service:latest .
```

#### 3.2 部署到 Kubernetes

```bash
# 创建 namespace
kubectl apply -f k8s/namespace.yaml

# 创建 ConfigMap
kubectl apply -f k8s/configmap.yaml

# 部署各个服务
kubectl apply -f k8s/user/deployment.yaml
kubectl apply -f k8s/product/deployment.yaml
kubectl apply -f k8s/trade/deployment.yaml
kubectl apply -f k8s/web/deployment.yaml

# 检查部署状态
kubectl get pods -n service-test
kubectl get svc -n service-test
```

### 4. 验证部署

```bash
# 查看所有 Pod 状态
kubectl get pods -n service-test

# 查看服务状态
kubectl get svc -n service-test

# 查看 Ingress
kubectl get ingress -n service-test

# 查看 Pod 日志
kubectl logs -f <pod-name> -n service-test

# 测试 web 服务（通过 NodePort）
curl http://<node-ip>:30888/api/user/1
```

## 注意事项

1. **etcd 服务**：确保 Kubernetes 集群中有 etcd 服务运行，或者修改 ConfigMap 中的 etcd 地址

2. **镜像仓库**：默认使用 GitHub Container Registry (ghcr.io)，需要确保有推送权限

3. **资源限制**：根据实际需求调整 deployment.yaml 中的资源限制

4. **健康检查**：web 服务使用 HTTP 健康检查，RPC 服务使用 TCP 健康检查

5. **服务依赖**：确保服务启动顺序（user/product → trade → web）

## 故障排查

### 镜像拉取失败

```bash
# 检查镜像是否存在
docker pull ghcr.io/your-org/service-test/web-service:latest

# 检查镜像仓库权限
kubectl describe pod <pod-name> -n service-test
```

### Pod 启动失败

```bash
# 查看 Pod 事件
kubectl describe pod <pod-name> -n service-test

# 查看 Pod 日志
kubectl logs <pod-name> -n service-test
```

### 服务无法访问

```bash
# 检查 Service 配置
kubectl get svc -n service-test -o yaml

# 检查 Endpoints
kubectl get endpoints -n service-test

# 测试服务连通性
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -n service-test -- curl http://web-service:8888/health
```

## 相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Kubernetes 文档](https://kubernetes.io/docs/)
- [go-zero 文档](https://go-zero.dev/)

