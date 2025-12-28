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
3. 创建命名空间（如 `your-namespace`）
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

### 问题 0：K8s API Server 证书问题（详细）

**错误信息**：
```
x509: certificate is valid for k8s-master, k8s-master-external, kubernetes, 
kubernetes.default, kubernetes.default.svc, kubernetes.default.svc.cluster.local, 
not k8s-master-internal
```

或：
```
x509: certificate is valid for 10.96.0.1, <内网IP>, not <公网IP>
```

**原因分析**：
- kubeadm 初始化时生成的 API Server 证书只包含了部分 SAN（Subject Alternative Names）
- 当使用公网 IP 或新的 DNS 名称访问时，证书验证失败
- GitHub Actions 从外网访问 K8s 集群需要公网 IP 在证书中

**完整解决步骤**：

```bash
# 1. 查看当前证书包含的 SAN
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"

# 2. 备份旧证书
cp /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver.crt.bak
cp /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/apiserver.key.bak

# 3. 删除旧证书（必须删除，否则不会重新生成）
rm /etc/kubernetes/pki/apiserver.crt
rm /etc/kubernetes/pki/apiserver.key

# 4. 重新生成证书，包含所有需要的 SAN
kubeadm init phase certs apiserver \
  --apiserver-cert-extra-sans=k8s-master-internal,k8s-master,k8s-master-external,<公网IP>,<内网IP>

# 5. 重启 API Server（通过移动 manifest 文件触发）
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 5
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# 6. 等待 API Server 重启
sleep 30

# 7. 验证证书
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"

# 8. 测试连接
kubectl get nodes
```

**生成外部访问的 KUBECONFIG**：
```bash
# 在 master 节点上执行
EXTERNAL_IP="<公网IP>"

# 复制现有配置
cp /etc/kubernetes/admin.conf /tmp/external-kubeconfig

# 替换内网地址为公网地址
sed -i "s|server: https://.*:6443|server: https://${EXTERNAL_IP}:6443|g" /tmp/external-kubeconfig

# Base64 编码后添加到 GitHub Secrets
cat /tmp/external-kubeconfig | base64 -w 0
```

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

**解决方案 A**：改用阿里云容器镜像服务
```yaml
# ci-cd.yml
env:
  REGISTRY: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com
  IMAGE_PREFIX: <your-namespace>

# deployment.yaml 中也要对应修改
image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/user-service:latest
```

**解决方案 B**：手动拉取并重新 tag（临时方案）
```bash
# 在有代理的机器上拉取
docker pull ghcr.io/<your-org>/<your-repo>/user-service:latest

# 保存为 tar
docker save ghcr.io/<your-org>/<your-repo>/user-service:latest -o user-service.tar

# 传输到 K8s 节点
scp user-service.tar root@<master-ip>:/tmp/

# 在 K8s 节点上导入
ctr -n k8s.io images import /tmp/user-service.tar
```

**解决方案 C**：配置镜像仓库代理（如果有私有代理）
```bash
# 在 K8s 节点上配置 containerd 代理
mkdir -p /etc/systemd/system/containerd.service.d/
cat > /etc/systemd/system/containerd.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://proxy:port"
Environment="HTTPS_PROXY=http://proxy:port"
Environment="NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF

systemctl daemon-reload
systemctl restart containerd
```

### 问题 3.1：镜像仓库地址不一致

**错误**：`ImagePullBackOff` - 镜像不存在

**原因**：CI/CD 推送到阿里云仓库，但 deployment.yaml 配置的是 ghcr.io

**排查步骤**：
```bash
# 1. 查看 CI/CD 配置的镜像仓库
grep -E "REGISTRY|IMAGE_PREFIX" .github/workflows/ci-cd.yml

# 2. 查看 deployment.yaml 配置的镜像地址
grep "image:" k8s/*/deployment.yaml

# 3. 确保两者一致
```

**解决**：统一镜像地址
```yaml
# deployment.yaml 中使用与 CI/CD 相同的仓库地址
image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/user-service:latest
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

### Pod 管理命令

```bash
# 查看所有 namespace 的 Pod
kubectl get pods -A

# 查看指定 namespace 的 Pod
kubectl get pods -n service-test

# 查看 Pod 详细信息（包括事件）
kubectl describe pod <pod-name> -n service-test

# 查看 Pod 日志
kubectl logs <pod-name> -n service-test

# 实时查看日志
kubectl logs -f <pod-name> -n service-test

# 查看之前容器的日志（如果容器重启过）
kubectl logs <pod-name> -n service-test --previous

# 进入 Pod 容器
kubectl exec -it <pod-name> -n service-test -- /bin/sh

# 删除 Pod（会自动重建）
kubectl delete pod <pod-name> -n service-test
```

### Deployment 管理命令

```bash
# 查看 Deployment
kubectl get deployment -n service-test

# 查看 Deployment 详情
kubectl describe deployment <deployment-name> -n service-test

# 查看 Deployment 使用的镜像
kubectl get deployment -n service-test -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'

# 更新镜像
kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n service-test

# 示例：更新 user-service 镜像
kubectl set image deployment/user-service user=<your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/user-service:latest -n service-test

# 重启 Deployment（触发滚动更新）
kubectl rollout restart deployment/<deployment-name> -n service-test

# 查看滚动更新状态
kubectl rollout status deployment/<deployment-name> -n service-test

# 回滚到上一版本
kubectl rollout undo deployment/<deployment-name> -n service-test

# 查看历史版本
kubectl rollout history deployment/<deployment-name> -n service-test

# 扩缩容
kubectl scale deployment/<deployment-name> --replicas=3 -n service-test
```

### Service 管理命令

```bash
# 查看 Service
kubectl get svc -n service-test

# 查看 Service 详情
kubectl describe svc <service-name> -n service-test

# 查看 Service 端点
kubectl get endpoints -n service-test
```

### ConfigMap 管理命令

```bash
# 查看 ConfigMap
kubectl get configmap -n service-test

# 查看 ConfigMap 内容
kubectl describe configmap <configmap-name> -n service-test

# 从文件创建/更新 ConfigMap
kubectl create configmap user-service-config \
  --from-file=user.yaml=k8s/etc/user.yaml \
  -n service-test --dry-run=client -o yaml | kubectl apply -f -

# 删除 ConfigMap
kubectl delete configmap <configmap-name> -n service-test
```

### 调试命令

```bash
# 查看节点状态
kubectl get nodes

# 查看节点详情
kubectl describe node <node-name>

# 查看集群事件
kubectl get events -n service-test --sort-by='.lastTimestamp'

# 查看资源使用情况
kubectl top pods -n service-test
kubectl top nodes

# 在集群内运行临时 Pod 进行调试
kubectl run debug --image=busybox --rm -it --restart=Never -n service-test -- /bin/sh

# 测试服务连通性
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -n service-test -- \
  curl -v http://web-service:8888/

# 测试 DNS 解析
kubectl run dns-test --image=busybox --rm -it --restart=Never -n service-test -- \
  nslookup etcd-service
```

### 镜像管理命令（在 K8s 节点上执行）

```bash
# 查看节点上的镜像（containerd）
ctr -n k8s.io images list

# 拉取镜像
ctr -n k8s.io images pull <image>

# 删除镜像
ctr -n k8s.io images rm <image>

# 导入镜像
ctr -n k8s.io images import <tar-file>

# 导出镜像
ctr -n k8s.io images export <tar-file> <image>
```

### 证书管理命令

```bash
# 查看 API Server 证书信息
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout

# 查看证书 SAN
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"

# 查看证书有效期
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# 重新生成 API Server 证书
kubeadm init phase certs apiserver --apiserver-cert-extra-sans=<额外的SAN>

# 查看 kubeadm 证书过期时间
kubeadm certs check-expiration
```

### YAML 应用命令

```bash
# 应用配置
kubectl apply -f <file.yaml>

# 应用目录下所有配置
kubectl apply -f k8s/

# 删除配置
kubectl delete -f <file.yaml>

# 查看将要应用的变更（dry-run）
kubectl apply -f <file.yaml> --dry-run=client

# 导出现有资源为 YAML
kubectl get deployment <name> -n service-test -o yaml > deployment.yaml
```

## 六、关键配置文件

### ci-cd.yml 核心配置

```yaml
env:
  REGISTRY: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com
  IMAGE_PREFIX: <your-namespace>

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
product-service: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/product-service:38455c2
trade-service: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/trade-service:38455c2
user-service: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/user-service:38455c2
web-service: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/web-service:38455c2
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
        image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/user-service:latest
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
        image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/product-service:latest
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
        image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/trade-service:latest
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
        image: <your-registry>.cn-hangzhou.personal.cr.aliyuncs.com/<your-namespace>/web-service:latest
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


## 十、部署经验总结

### 10.1 证书问题排查流程

当遇到 `x509: certificate is valid for ... not xxx` 错误时：

1. **确认访问方式**：是通过 IP 还是域名访问？
2. **查看当前证书 SAN**：
   ```bash
   openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"
   ```
3. **确定需要添加的 SAN**：
   - 公网 IP（如 x.x.x.x）
   - 内网 IP（如 10.0.x.x）
   - DNS 名称（如 k8s-master-internal）
4. **重新生成证书**（见问题 0 的解决步骤）

### 10.2 镜像拉取问题排查流程

当遇到 `ImagePullBackOff` 错误时：

1. **查看 Pod 事件**：
   ```bash
   kubectl describe pod <pod-name> -n service-test | grep -A10 Events
   ```
2. **确认镜像地址是否正确**：
   ```bash
   # 查看 deployment 配置的镜像
   kubectl get deployment <name> -n service-test -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```
3. **确认镜像是否存在**：
   - 登录镜像仓库 Web 界面查看
   - 或在有网络的机器上尝试 `docker pull <image>`
4. **确认镜像仓库认证**：
   - 公开仓库：无需认证
   - 私有仓库：需要创建 imagePullSecret
5. **网络问题**：
   - 国内服务器访问 ghcr.io/docker.io 可能超时
   - 解决：使用国内镜像仓库（阿里云、腾讯云等）

### 10.3 服务启动问题排查流程

当服务 `CrashLoopBackOff` 时：

1. **查看日志**：
   ```bash
   kubectl logs <pod-name> -n service-test
   kubectl logs <pod-name> -n service-test --previous  # 查看上次崩溃的日志
   ```
2. **常见原因**：
   - 配置文件错误（如 etcd 地址为空）
   - 依赖服务未就绪（如 etcd 未启动）
   - 端口冲突
   - 资源不足

### 10.4 CI/CD 与 K8s 配置一致性检查清单

| 检查项 | CI/CD 配置 | K8s 配置 | 状态 |
|--------|-----------|----------|------|
| 镜像仓库地址 | `env.REGISTRY` | `deployment.yaml image:` | 必须一致 |
| 镜像名称格式 | `{REGISTRY}/{IMAGE_PREFIX}/{service}-service` | 同左 | 必须一致 |
| 镜像 Tag | `${GITHUB_SHA::7}` 或 `latest` | 同左 | 必须一致 |
| 服务端口 | `matrix.service.port` | `containerPort` | 必须一致 |
| ConfigMap 名称 | `{service}-service-config` | `volumes.configMap.name` | 必须一致 |
| 配置文件路径 | `k8s/etc/{service}.yaml` | `/app/etc` | 必须一致 |

### 10.5 快速修复命令速查

```bash
# 镜像拉取失败 - 更新镜像地址
kubectl set image deployment/user-service user=<正确的镜像地址> -n service-test

# 配置错误 - 更新 ConfigMap 后重启
kubectl create configmap user-service-config --from-file=user.yaml=k8s/etc/user.yaml -n service-test --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/user-service -n service-test

# 服务卡住 - 删除 Pod 强制重建
kubectl delete pod -l app=user-service -n service-test

# 清理失败的 Pod
kubectl delete pod --field-selector=status.phase=Failed -n service-test

# 查看所有问题 Pod
kubectl get pods -n service-test | grep -v Running | grep -v Completed
```

### 10.6 本次部署关键配置

**集群信息**：
- Master: <公网IP> (公网) / <内网IP> (内网)
- Worker1: <公网IP> / <内网IP>
- Worker2: <公网IP> / <内网IP>

**镜像仓库**：
- 地址: `<your-registry>.cn-hangzhou.personal.cr.aliyuncs.com`
- 命名空间: `<your-namespace>`
- 镜像格式: `{仓库地址}/<your-namespace>/{service}-service:{tag}`

**服务端口**：
| 服务 | 端口 | 类型 | NodePort |
|------|------|------|----------|
| etcd | 2379 | ClusterIP | - |
| user-service | 9001 | ClusterIP | - |
| product-service | 9002 | ClusterIP | - |
| trade-service | 9003 | ClusterIP | - |
| web-service | 8888 | NodePort | 30888 |

**访问方式**：
- 集群内部：`http://{service-name}:{port}`
- 外部访问：`http://{节点IP}:30888`
