# GitHub CI/CD 部署指南

本文档记录使用 GitHub Actions 实现 go-zero 微服务项目 CI/CD 部署到 Kubernetes 集群的完整过程。

## 一、项目架构

```
service_test/
├── .github/workflows/ci-cd.yml    # CI/CD 配置
├── dockerfiles/                    # Dockerfile 文件
│   ├── Dockerfile.user
│   ├── Dockerfile.product
│   ├── Dockerfile.trade
│   └── Dockerfile.web
├── k8s/                           # Kubernetes 配置
│   ├── etc/                       # 服务配置文件（ConfigMap 数据源）
│   │   ├── user.yaml
│   │   ├── product.yaml
│   │   ├── trade.yaml
│   │   └── web.yaml
│   ├── user/deployment.yaml
│   ├── product/deployment.yaml
│   ├── trade/deployment.yaml
│   ├── web/deployment.yaml
│   ├── etcd/deployment.yaml
│   ├── namespace.yaml
│   └── configmap.yaml
├── api/web/                       # HTTP API 网关 (端口 8888)
└── rpc/                           # gRPC 服务
    ├── user/                      # 端口 9001
    ├── product/                   # 端口 9002
    └── trade/                     # 端口 9003
```

## 二、实施步骤

### 步骤 1：配置 GitHub Actions 权限

在 ci-cd.yml 中添加 packages 写入权限：

```yaml
permissions:
  contents: read
  packages: write
```

### 步骤 2：配置阿里云镜像仓库

1. 登录 https://cr.console.aliyun.com/
2. 选择地域（华东1杭州）
3. 创建命名空间（如 `tutengdihuang`）
4. 设置访问凭证

### 步骤 3：配置 GitHub Secrets

在仓库 Settings → Secrets 添加：

| Secret 名称 | 说明 |
|-------------|------|
| `KUBECONFIG` | K8s 配置文件（base64 编码） |
| `ALIYUN_REGISTRY_USERNAME` | 阿里云镜像仓库用户名 |
| `ALIYUN_REGISTRY_PASSWORD` | 阿里云镜像仓库密码 |

生成 KUBECONFIG：
```bash
cat ~/.kube/config | base64 -w 0
```

### 步骤 4：配置 K8s API Server 证书

确保证书包含公网 IP：
```bash
kubeadm init phase certs apiserver \
  --apiserver-cert-extra-sans=<公网IP>,<内网IP>,k8s-master
```

### 步骤 5：部署 etcd

使用阿里云镜像（国内可访问）：
```yaml
image: registry.aliyuncs.com/google_containers/etcd:3.5.9-0
```

### 步骤 6：配置服务 ConfigMap

将配置文件放在 `k8s/etc/` 目录，CI/CD 自动创建 ConfigMap：
```bash
kubectl create configmap user-service-config \
  --from-file=user.yaml=k8s/etc/user.yaml \
  -n service-test --dry-run=client -o yaml | kubectl apply -f -
```

### 步骤 7：配置 Deployment 挂载 ConfigMap

```yaml
spec:
  containers:
  - name: user
    volumeMounts:
    - name: config
      mountPath: /app/etc
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: user-service-config
```

## 三、遇到的问题及解决方案

### 问题 1：GitHub Packages 推送权限不足

**错误**：`denied: installation not allowed to Create organization package`

**原因**：CI/CD 缺少 packages 写入权限

**解决**：
```yaml
permissions:
  contents: read
  packages: write
```

### 问题 2：K8s API Server 证书不包含公网 IP

**错误**：`x509: certificate is valid for 10.96.0.1, 10.0.3.231, not <公网IP>`

**原因**：kubeadm 初始化时未指定公网 IP

**解决**：
```bash
# 备份并删除旧证书
mv /etc/kubernetes/pki/apiserver.{crt,key} /tmp/

# 重新生成证书
kubeadm init phase certs apiserver \
  --apiserver-cert-extra-sans=k8s-master-internal,<公网IP>,<内网IP>

# 重启 API Server
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

### 问题 3：中国服务器无法拉取 ghcr.io 镜像

**错误**：`ImagePullBackOff` 或拉取超时

**原因**：国内网络访问 ghcr.io 不稳定

**解决**：改用阿里云容器镜像服务
```yaml
env:
  REGISTRY: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com
  IMAGE_PREFIX: tutengdihuang
```

### 问题 4：阿里云个人版不支持 buildx 缓存

**错误**：`403 Forbidden: unknown manifest class for application/vnd.buildkit.cacheconfig.v0`

**原因**：阿里云个人版镜像仓库不支持 buildx 缓存格式

**解决**：删除 cache-from 和 cache-to 配置
```yaml
# 删除这两行
cache-from: type=registry,ref=.../buildcache
cache-to: type=registry,ref=.../buildcache,mode=max
```

### 问题 5：镜像 Tag 不匹配

**错误**：`image not found: xxx:38455c27`

**原因**：Build 阶段推送 7 位 SHA，Deploy 阶段使用 8 位 SHA

**解决**：统一使用 7 位
```yaml
# Build 阶段
type=sha,prefix=

# Deploy 阶段
IMAGE_TAG=${GITHUB_SHA::7}
```

### 问题 6：服务启动失败 - empty etcd hosts

**错误**：`empty etcd hosts`

**原因**：镜像中的配置文件 etcd 地址为空，go-zero 不会自动读取环境变量

**解决**：使用 ConfigMap 挂载配置文件到 `/app/etc`，覆盖镜像中的默认配置

### 问题 7：服务循环依赖导致启动失败

**错误**：`rpc dial: etcd://etcd-service:2379/user.rpc, error: context deadline exceeded`

**原因**：user-service 依赖 trade-service，trade-service 依赖 user-service，互相等待

**解决**：在配置中添加 `NonBlock: true`
```yaml
# k8s/etc/user.yaml
TradeRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: trade.rpc
  NonBlock: true
  Timeout: 5000
```

### 问题 8：健康检查失败

**错误**：`Readiness probe failed: HTTP probe failed with statuscode: 404`

**原因**：web-service 没有实现 `/health` 端点

**解决**：
- 方案 A：在代码中添加 `/health` 端点
- 方案 B：去掉 deployment 中的健康检查配置
```bash
kubectl patch deployment web-service -n service-test --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}
]'
```

### 问题 9：多个 Pod 版本同时运行

**原因**：K8s 滚动更新机制，新 Pod 无法 Ready 时旧 Pod 保留

**解决**：
```bash
# 缩容到 1 个副本
kubectl scale deployment xxx --replicas=1 -n service-test

# 或删除重建
kubectl delete deployment xxx -n service-test
kubectl create deployment xxx --image=xxx -n service-test
```

## 四、CI/CD 流程说明

```
Push 代码
    ↓
Test 阶段
├── 代码检出
├── Go 环境配置
├── 运行测试
└── 构建验证
    ↓
Detect-Changes 阶段（增量构建）
├── 检测变更文件
└── 输出各服务变更状态
    ↓
Build 阶段（只构建有变更的服务）
├── 检查是否需要构建
├── 登录阿里云镜像仓库
├── 构建 Docker 镜像
└── 推送镜像（tag: commit SHA 前 7 位 + latest）
    ↓
Deploy 阶段（只部署有变更的服务）
├── 配置 kubectl（使用 KUBECONFIG secret）
├── 创建 ConfigMap（从 k8s/etc/ 目录）
├── 更新有变更服务的 deployment 镜像
└── 等待 rollout 完成
```

### 增量构建规则

| 变更文件 | 触发构建的服务 |
|----------|----------------|
| `api/web/*` | web |
| `rpc/user/*` | user |
| `rpc/product/*` | product |
| `rpc/trade/*` | trade |
| `go.mod`、`go.sum`、`dockerfiles/*` | 所有服务 |

### 手动触发

通过 GitHub Actions 的 `workflow_dispatch` 可以手动选择构建：
- `all` - 构建所有服务
- `web` / `user` / `product` / `trade` - 只构建指定服务

### 变更检测实现

```yaml
# detect-changes job
- name: Detect changes
  run: |
    # 获取变更文件
    CHANGED_FILES=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }})
    
    # 检测公共文件变更
    if echo "$CHANGED_FILES" | grep -qE "^(go\.mod|go\.sum|dockerfiles/)"; then
      echo "common=true" >> $GITHUB_OUTPUT
    fi
    
    # 检测各服务变更
    if echo "$CHANGED_FILES" | grep -qE "^api/web/"; then
      echo "web=true" >> $GITHUB_OUTPUT
    fi
    # ... 其他服务类似

# build job 中检查是否需要构建
- name: Check if build needed
  run: |
    if [ "${{ needs.detect-changes.outputs.common }}" == "true" ]; then
      echo "skip=false" >> $GITHUB_OUTPUT  # 公共文件变更，需要构建
    elif [ "${{ needs.detect-changes.outputs[matrix.service.name] }}" == "true" ]; then
      echo "skip=false" >> $GITHUB_OUTPUT  # 服务有变更，需要构建
    else
      echo "skip=true" >> $GITHUB_OUTPUT   # 无变更，跳过
    fi
```

## 五、常用命令

```bash
# 查看 Pod 状态
kubectl get pods -n service-test

# 查看 Pod 详情
kubectl describe pod <pod-name> -n service-test

# 查看日志
kubectl logs -f <pod-name> -n service-test

# 手动更新镜像
kubectl set image deployment/user-service \
  user=registry/namespace/user-service:tag -n service-test

# 重启部署
kubectl rollout restart deployment/user-service -n service-test

# 回滚
kubectl rollout undo deployment/user-service -n service-test

# 手动拉取镜像（在 K8s 节点上）
ctr -n k8s.io images pull <image>
```

## 六、关键配置文件

### ci-cd.yml 核心配置

```yaml
env:
  REGISTRY: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com
  IMAGE_PREFIX: tutengdihuang

# 登录阿里云
- name: Log in to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ secrets.ALIYUN_REGISTRY_USERNAME }}
    password: ${{ secrets.ALIYUN_REGISTRY_PASSWORD }}

# 镜像 tag
tags: |
  type=sha,prefix=
  type=raw,value=latest

# 部署时使用 7 位 SHA
IMAGE_TAG=${GITHUB_SHA::7}
```

### 服务配置示例 (k8s/etc/user.yaml)

```yaml
Name: user.rpc
ListenOn: 0.0.0.0:9001
Etcd:
  Hosts:
    - etcd-service:2379
  Key: user.rpc
TradeRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: trade.rpc
  NonBlock: true
  Timeout: 5000
```

## 七、部署效果展示

### 集群 Pod 状态

```bash
$ kubectl get pods -n service-test
NAME                               READY   STATUS    RESTARTS   AGE
etcd-b7d89b969-7gf9x               1/1     Running   0          4h35m
product-service-587fc8b7db-lprqr   1/1     Running   0          5m
trade-service-585b5b965-b2xlj      1/1     Running   0          5m
user-service-867dccd6bc-qbhmg      1/1     Running   0          7m
web-service-544484dc9-sgd6b        1/1     Running   0          5m
```

### 服务列表

```bash
$ kubectl get svc -n service-test
NAME              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
etcd-service      ClusterIP   10.103.216.99    <none>        2379/TCP         4h
product-service   ClusterIP   10.108.244.79    <none>        9002/TCP         4h
trade-service     ClusterIP   10.105.249.160   <none>        9003/TCP         4h
user-service      ClusterIP   10.105.170.2     <none>        9001/TCP         4h
web-service       NodePort    10.107.93.84     <none>        8888:30888/TCP   4h
```

### Deployment 镜像信息

```bash
$ kubectl get deployment -n service-test -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'
etcd: registry.aliyuncs.com/google_containers/etcd:3.5.9-0
product-service: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/product-service:38455c2
trade-service: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/trade-service:38455c2
user-service: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/user-service:38455c2
web-service: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/web-service:38455c2
```

### 服务日志

```bash
$ kubectl logs user-service-867dccd6bc-qbhmg -n service-test --tail=5
Starting rpc server at 0.0.0.0:9001...

$ kubectl logs web-service-544484dc9-sgd6b -n service-test --tail=5
Starting server at 0.0.0.0:8888...
```

### 访问测试

```bash
# 通过 NodePort 访问 web-service
$ curl http://<节点IP>:30888/
404 page not found  # 正常响应，说明服务已启动（没有配置根路径）

# 集群内部访问
$ kubectl exec -it user-service-xxx -n service-test -- wget -qO- http://etcd-service:2379/version
{"etcdserver":"3.5.9","etcdcluster":"3.5.0"}
```

### CI/CD 执行效果

```
✓ Test (1m 30s)
  ├── Checkout code
  ├── Set up Go
  ├── Run tests
  └── Build verification - 所有服务构建成功

✓ Detect-Changes (10s)
  └── user=true, product=false, trade=false, web=false

✓ Build (3m 20s)
  ├── user-service - 构建并推送
  ├── product-service - 跳过（无变更）
  ├── trade-service - 跳过（无变更）
  └── web-service - 跳过（无变更）

✓ Deploy (2m 10s)
  ├── ConfigMap 更新
  ├── user-service 部署
  └── 其他服务跳过
```

## 八、各服务 Deployment 配置详情

### etcd Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: etcd
  namespace: service-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
      - name: etcd
        image: registry.aliyuncs.com/google_containers/etcd:3.5.9-0
        ports:
        - containerPort: 2379
        - containerPort: 2380
        command:
        - etcd
        - --listen-client-urls=http://0.0.0.0:2379
        - --advertise-client-urls=http://etcd-service:2379
---
apiVersion: v1
kind: Service
metadata:
  name: etcd-service
  namespace: service-test
spec:
  type: ClusterIP
  ports:
  - port: 2379
    targetPort: 2379
  selector:
    app: etcd
```

### user-service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: service-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user
        image: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/user-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 9001
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /app/etc
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: user-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: service-test
spec:
  type: ClusterIP
  ports:
  - port: 9001
    targetPort: 9001
    name: grpc
  selector:
    app: user-service
```

### product-service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: service-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product
        image: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/product-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 9002
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /app/etc
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: product-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: service-test
spec:
  type: ClusterIP
  ports:
  - port: 9002
    targetPort: 9002
    name: grpc
  selector:
    app: product-service
```

### trade-service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trade-service
  namespace: service-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trade-service
  template:
    metadata:
      labels:
        app: trade-service
    spec:
      containers:
      - name: trade
        image: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/trade-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 9003
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /app/etc
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: trade-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: trade-service
  namespace: service-test
spec:
  type: ClusterIP
  ports:
  - port: 9003
    targetPort: 9003
    name: grpc
  selector:
    app: trade-service
```

### web-service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-service
  namespace: service-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-service
  template:
    metadata:
      labels:
        app: web-service
    spec:
      containers:
      - name: web
        image: crpi-xxx.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang/web-service:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8888
          name: http
        volumeMounts:
        - name: config
          mountPath: /app/etc
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: web-service-config
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: service-test
spec:
  type: NodePort
  ports:
  - port: 8888
    targetPort: 8888
    nodePort: 30888
    name: http
  selector:
    app: web-service
```

## 九、各服务 ConfigMap 配置

### user-service-config

```yaml
# k8s/etc/user.yaml
Name: user.rpc
ListenOn: 0.0.0.0:9001
Etcd:
  Hosts:
    - etcd-service:2379
  Key: user.rpc
TradeRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: trade.rpc
  NonBlock: true
  Timeout: 5000
```

### product-service-config

```yaml
# k8s/etc/product.yaml
Name: product.rpc
ListenOn: 0.0.0.0:9002
Etcd:
  Hosts:
    - etcd-service:2379
  Key: product.rpc
```

### trade-service-config

```yaml
# k8s/etc/trade.yaml
Name: trade.rpc
ListenOn: 0.0.0.0:9003
Etcd:
  Hosts:
    - etcd-service:2379
  Key: trade.rpc
UserRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: user.rpc
  NonBlock: true
  Timeout: 5000
ProductRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: product.rpc
  NonBlock: true
  Timeout: 5000
```

### web-service-config

```yaml
# k8s/etc/web.yaml
Name: web-api
Host: 0.0.0.0
Port: 8888
UserRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: user.rpc
  NonBlock: true
  Timeout: 5000
ProductRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: product.rpc
  NonBlock: true
  Timeout: 5000
TradeRpc:
  Etcd:
    Hosts:
      - etcd-service:2379
    Key: trade.rpc
  NonBlock: true
  Timeout: 5000
```
