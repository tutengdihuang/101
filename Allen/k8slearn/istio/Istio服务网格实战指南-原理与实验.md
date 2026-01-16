# Istio 服务网格实战指南 - 原理与实验

> 从流量劫持到安全认证，一文搞懂 Istio 的核心魔法

## 写在前面

学 Istio 就像学开车：光看说明书永远学不会，必须上路练。本文将带你从原理到实验，真正理解 Istio 是如何工作的。

**本文特点**：
- 🎯 **原理先行**：每个功能先讲清楚"为什么"和"怎么做"
- 🔬 **实验验证**：每个原理都有对应的实验，眼见为实
- 🎭 **深入浅出**：用生活比喻解释技术概念
- 📋 **可复制**：所有命令和 YAML 都可以直接使用

---

## 目录

1. [Sidecar 流量劫持原理](#一sidecar-流量劫持原理)
2. [Gateway 与七层路由](#二gateway-与七层路由)
3. [灰度发布与金丝雀部署](#三灰度发布与金丝雀部署)
4. [故障注入与容错](#四故障注入与容错)
5. [mTLS 与 PeerAuthentication](#五mtls-与-peerauthentication)
6. [AuthorizationPolicy 访问控制](#六authorizationpolicy-访问控制)
7. [分布式追踪](#七分布式追踪)

---

## 一、Sidecar 流量劫持原理

### 1.1 核心概念

Sidecar 是 Istio 的灵魂。它像一个"隐形保镖"，被注入到每个 Pod 中，拦截所有进出的流量。

**生活比喻**：

想象你住在一个高档小区：
- **没有 Sidecar**：你直接出门，没人知道你去哪、干什么
- **有 Sidecar**：门口有个保安（Envoy），记录你的行踪，检查你的身份，必要时还能拦截你

```
┌─────────────────────────────────────────────────────────────┐
│                        Pod                                   │
│  ┌─────────────┐                      ┌─────────────┐       │
│  │   应用容器   │ ←──── iptables ────→ │   Envoy     │       │
│  │  (你的代码)  │       流量劫持        │  (Sidecar)  │       │
│  └─────────────┘                      └─────────────┘       │
│        ↑                                    ↑               │
│        │                                    │               │
│   localhost:80                         15001/15006          │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 流量劫持原理

Istio 使用 **iptables** 规则劫持流量。这就像在小区门口设置了一个"强制检查站"。

**出站流量（你要出门）**：
```
1. 应用发起请求（curl nginx）
2. iptables 劫持到 15001 端口（保安拦住你）
3. Envoy 处理请求（保安检查你的目的地）
4. 根据规则选择目标（保安告诉你走哪条路）
5. 请求发送出去（放行）
```

**入站流量（有人来找你）**：
```
1. 请求到达 Pod
2. iptables 劫持到 15006 端口
3. Envoy 检查请求
4. 转发到本地应用
```

### 1.3 关键端口

| 端口 | 名称 | 作用 |
|------|------|------|
| 15001 | virtualOutbound | 出站流量入口 |
| 15006 | virtualInbound | 入站流量入口 |
| 15090 | Prometheus | 指标暴露 |
| 15021 | Health Check | 健康检查 |

### 1.4 Envoy 配置四要素

Envoy 的配置就像导航系统：

| 组件 | 说明 | 类比 |
|------|------|------|
| **Listener** | 监听器，接收流量 | 收费站入口 |
| **Route** | 路由规则，决定去哪 | 导航路线 |
| **Cluster** | 上游服务集群 | 目的地城市 |
| **Endpoint** | 具体的服务实例 | 具体地址 |


### 1.5 🔬 实验：观察流量劫持

**准备工作**：

```bash
# 创建命名空间并启用 Sidecar 注入
kubectl create ns sidecar
kubectl label ns sidecar istio-injection=enabled
```

**部署测试应用**：

```yaml
# nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```yaml
# toolbox.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: toolbox
  template:
    metadata:
      labels:
        app: toolbox
    spec:
      containers:
      - name: toolbox
        image: centos
        command: ["/bin/bash", "-c", "sleep infinity"]
```

```bash
kubectl apply -f nginx.yaml -n sidecar
kubectl apply -f toolbox.yaml -n sidecar
```

**查看 Envoy 配置**：

```bash
# 获取 Pod 名称
POD=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')

# 查看 Listener（收费站入口）
istioctl pc listener -n sidecar $POD

# 查看 Route（导航路线）
istioctl pc route -n sidecar $POD

# 查看 Cluster（目的地城市）
istioctl pc cluster -n sidecar $POD

# 查看 Endpoint（具体地址）
istioctl pc endpoint -n sidecar $POD | grep nginx
```

**测试访问并观察日志**：

```bash
# 从 toolbox 访问 nginx
kubectl exec -it $POD -n sidecar -c toolbox -- curl nginx

# 查看 Sidecar 日志
kubectl logs $POD -n sidecar -c istio-proxy --tail=5
```

**深入查看流量路径**：

```bash
# 1. 查看 15001 listener（出站入口）
istioctl pc listener -n sidecar $POD --port 15001 -o json | head -30

# 2. 查看 80 端口的路由
istioctl pc route -n sidecar $POD --name=80

# 3. 查看 nginx 的 endpoint
istioctl pc endpoint -n sidecar $POD | grep nginx
```

---


## 二、Gateway 与七层路由

### 2.1 核心概念

Gateway 是 Istio 的"大门"，负责管理进出网格的流量。

**生活比喻**：
- **Gateway** = 机场航站楼（统一入口）
- **VirtualService** = 航班信息板（告诉你去哪个登机口）

```
                    ┌─────────────────────────────────────┐
                    │           Istio Ingress Gateway      │
   外部流量 ───────→│  (统一入口，处理 TLS、路由等)        │
                    └─────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ↓                 ↓                 ↓
              ┌──────────┐     ┌──────────┐     ┌──────────┐
              │ Service A │     │ Service B │     │ Service C │
              └──────────┘     └──────────┘     └──────────┘
```

### 2.2 Gateway + VirtualService 配置

**Gateway**：定义入口规则（监听哪个端口、哪个域名）

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: simple
spec:
  selector:
    istio: ingressgateway  # 使用 Istio 的 Ingress Gateway
  servers:
    - hosts:
        - simple.cncamp.io  # 监听的域名
      port:
        name: http-simple
        number: 80
        protocol: HTTP
```

**VirtualService**：定义路由规则（流量去哪）

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: simple
spec:
  gateways:
    - simple  # 关联的 Gateway
  hosts:
    - simple.cncamp.io
  http:
    - match:
        - port: 80
      route:
        - destination:
            host: simple.simple.svc.cluster.local
            port:
              number: 80
```

### 2.3 🔬 实验：HTTP Gateway

```bash
# 创建命名空间
kubectl create ns simple

# 部署应用
cat <<EOF | kubectl apply -n simple -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple
  template:
    metadata:
      labels:
        app: simple
    spec:
      containers:
      - name: simple
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: simple
spec:
  selector:
    app: simple
  ports:
  - port: 80
    targetPort: 80
EOF

# 部署 Gateway 和 VirtualService
cat <<EOF | kubectl apply -n simple -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: simple
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - simple.cncamp.io
      port:
        name: http-simple
        number: 80
        protocol: HTTP
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: simple
spec:
  gateways:
    - simple
  hosts:
    - simple.cncamp.io
  http:
    - match:
        - port: 80
      route:
        - destination:
            host: simple.simple.svc.cluster.local
            port:
              number: 80
EOF

# 获取 Ingress IP
export INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# 如果是 NodePort，使用：
# export INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

# 测试访问
curl -H "Host: simple.cncamp.io" http://$INGRESS_IP/ -v
```


### 2.4 🔬 实验：HTTPS Gateway

```bash
# 创建命名空间
kubectl create ns securesvc
kubectl label ns securesvc istio-injection=enabled

# 生成自签名证书
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=cncamp Inc./CN=*.cncamp.io' \
  -keyout cncamp.io.key -out cncamp.io.crt

# 创建 TLS Secret
kubectl create -n istio-system secret tls cncamp-credential \
  --key=cncamp.io.key --cert=cncamp.io.crt

# 部署应用和 HTTPS Gateway
cat <<EOF | kubectl apply -n securesvc -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpsserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpsserver
  template:
    metadata:
      labels:
        app: httpsserver
    spec:
      containers:
      - name: httpsserver
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpsserver
spec:
  selector:
    app: httpsserver
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpsserver
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - httpsserver.cncamp.io
      port:
        name: https
        number: 443
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: cncamp-credential
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpsserver
spec:
  gateways:
    - httpsserver
  hosts:
    - httpsserver.cncamp.io
  http:
    - route:
        - destination:
            host: httpsserver
            port:
              number: 80
EOF

# 测试 HTTPS 访问
curl --resolve httpsserver.cncamp.io:443:$INGRESS_IP \
  https://httpsserver.cncamp.io/ -v -k
```

---

## 三、灰度发布与金丝雀部署

### 3.1 核心概念

灰度发布就像"试吃"：新菜品先让少数顾客试吃，反馈好再推广。

**传统方式 vs Istio 方式**：

| 方面 | 传统方式 | Istio 方式 |
|------|---------|-----------|
| 实现 | 改代码、改配置 | 改 YAML 配置 |
| 生效 | 重新部署 | 秒级生效 |
| 回滚 | 重新部署 | 改配置即可 |
| 粒度 | 粗粒度 | 可按 Header、用户等精细控制 |

### 3.2 两种灰度策略

**策略一：按比例分流**
```
90% 流量 → v1（老版本）
10% 流量 → v2（新版本）
```

**策略二：按条件分流**
```
Header 包含 user: jesse → v2（新版本）
其他请求 → v1（老版本）
```


### 3.3 🔬 实验：金丝雀部署

**步骤 1：部署 v1 版本**

```bash
# 创建命名空间
kubectl create ns canary
kubectl label ns canary istio-injection=enabled

# 部署 v1 版本
cat <<EOF | kubectl apply -n canary -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary
      version: v1
  template:
    metadata:
      labels:
        app: canary
        version: v1
    spec:
      containers:
      - name: canary
        image: nginx
        ports:
        - containerPort: 80
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "This is version 1" > /usr/share/nginx/html/hello
          nginx -g "daemon off;"
---
apiVersion: v1
kind: Service
metadata:
  name: canary
spec:
  selector:
    app: canary
  ports:
  - port: 80
    targetPort: 80
EOF

# 部署 toolbox 用于测试
cat <<EOF | kubectl apply -n canary -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: toolbox
  template:
    metadata:
      labels:
        app: toolbox
    spec:
      containers:
      - name: toolbox
        image: centos
        command: ["/bin/bash", "-c", "sleep infinity"]
EOF
```

**步骤 2：部署 v2 版本**

```bash
cat <<EOF | kubectl apply -n canary -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary
      version: v2
  template:
    metadata:
      labels:
        app: canary
        version: v2
    spec:
      containers:
      - name: canary
        image: nginx
        ports:
        - containerPort: 80
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "This is version 2 - NEW!" > /usr/share/nginx/html/hello
          nginx -g "daemon off;"
EOF
```

**步骤 3：配置基于 Header 的路由**

```bash
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - match:
        - headers:
            user:
              exact: jesse  # Header 匹配
      route:
        - destination:
            host: canary
            subset: v2
    - route:
      - destination:
          host: canary
          subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: canary
spec:
  host: canary
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

**步骤 4：测试**

```bash
# 获取 toolbox Pod
TOOLBOX=$(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}')

# 普通请求 → v1
kubectl exec -it $TOOLBOX -n canary -- curl canary/hello
# 输出：This is version 1

# 带 Header 的请求 → v2
kubectl exec -it $TOOLBOX -n canary -- curl canary/hello -H "user: jesse"
# 输出：This is version 2 - NEW!

# 多次测试验证
for i in {1..5}; do
  echo "=== 普通请求 $i ==="
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
done

for i in {1..5}; do
  echo "=== VIP 请求 $i ==="
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello -H "user: jesse"
done
```

**步骤 5：按比例分流（可选）**

```bash
# 修改为 90-10 分流
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - route:
      - destination:
          host: canary
          subset: v1
        weight: 90
      - destination:
          host: canary
          subset: v2
        weight: 10
EOF

# 测试 10 次，大约 1 次会到 v2
for i in {1..10}; do
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
done
```

---


## 四、故障注入与容错

### 4.1 核心概念

故障注入就像"消防演习"：在可控环境下模拟故障，看系统会不会崩溃。

**两种故障类型**：

| 类型 | 说明 | 用途 |
|------|------|------|
| **延迟注入** | 人为增加响应时间 | 测试超时处理 |
| **错误注入** | 人为返回错误码 | 测试错误处理 |

**生活比喻**：
- **延迟注入** = 故意让外卖小哥晚送 30 分钟，看你会不会投诉
- **错误注入** = 故意送错餐，看你会不会退款

### 4.2 超时与重试

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
    timeout: 3s           # 超时时间
    retries:
      attempts: 3         # 重试次数
      perTryTimeout: 1s   # 每次重试超时
      retryOn: 5xx,reset,connect-failure
```

### 4.3 🔬 实验：故障注入

**延迟注入**：

```bash
# 在 canary 命名空间注入 5 秒延迟
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - fault:
        delay:
          percentage:
            value: 100    # 100% 请求
          fixedDelay: 5s  # 延迟 5 秒
      route:
        - destination:
            host: canary
            subset: v1
EOF

# 测试（会等待 5 秒）
time kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
```

**错误注入**：

```bash
# 注入 50% 的 500 错误
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - fault:
        abort:
          percentage:
            value: 50     # 50% 请求
          httpStatus: 500 # 返回 500
      route:
        - destination:
            host: canary
            subset: v1
EOF

# 测试 10 次，大约 5 次会返回 500
for i in {1..10}; do
  echo "=== 请求 $i ==="
  kubectl exec -it $TOOLBOX -n canary -- curl -s -o /dev/null -w "%{http_code}" canary/hello
  echo ""
done
```

**超时配置**：

```bash
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - route:
        - destination:
            host: canary
            subset: v1
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
EOF
```

**清理故障注入**：

```bash
# 恢复正常路由
cat <<EOF | kubectl apply -n canary -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
    - canary
  http:
    - route:
        - destination:
            host: canary
            subset: v1
EOF
```

---


## 五、mTLS 与 PeerAuthentication

### 5.1 核心概念

mTLS（双向 TLS）让服务间通信自动加密，而且双方都要验证身份。

**生活比喻**：

| 场景 | 没有 mTLS | 有 mTLS |
|------|----------|---------|
| 通话 | 明文通话，可被窃听 | 加密通话，无法窃听 |
| 身份 | 不验证对方身份 | 双方都要出示"身份证" |
| 证书 | 手动管理 | Istio 自动签发和轮换 |

```
┌─────────────────────────────────────────────────────────┐
│                     Istiod (CA)                         │
│                   证书颁发机构                           │
│              自动签发、自动轮换证书                       │
└─────────────────────────────────────────────────────────┘
                        ↓ 证书下发
┌─────────────────────────────────────────────────────────┐
│  ┌──────────────┐          ┌──────────────┐            │
│  │   服务 A      │  mTLS   │   服务 B      │            │
│  │ ┌──────────┐ │ ←────→  │ ┌──────────┐ │            │
│  │ │  Envoy   │ │ 加密通信 │ │  Envoy   │ │            │
│  │ │ (证书)   │ │          │ │ (证书)   │ │            │
│  │ └──────────┘ │          │ └──────────┘ │            │
│  └──────────────┘          └──────────────┘            │
└─────────────────────────────────────────────────────────┘
```

### 5.2 PeerAuthentication 三种模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **PERMISSIVE** | 宽松模式，接受 mTLS 和明文 | 迁移过渡期 |
| **STRICT** | 严格模式，只接受 mTLS | 生产环境 |
| **DISABLE** | 禁用 mTLS | 特殊场景 |

**配置优先级**：服务级别 > 命名空间级别 > 全局级别

### 5.3 🔬 实验：mTLS 认证

**步骤 1：准备测试环境**

```bash
# 创建三个命名空间
kubectl create ns foo
kubectl create ns bar
kubectl create ns legacy

# foo 和 bar 启用 Sidecar 注入
kubectl label ns foo istio-injection=enabled
kubectl label ns bar istio-injection=enabled
# legacy 不启用（模拟遗留系统）

# 部署 httpbin 和 sleep 到各命名空间
# foo 和 bar 会自动注入 Sidecar
kubectl apply -f samples/httpbin/httpbin.yaml -n foo
kubectl apply -f samples/sleep/sleep.yaml -n foo
kubectl apply -f samples/httpbin/httpbin.yaml -n bar
kubectl apply -f samples/sleep/sleep.yaml -n bar

# legacy 不注入 Sidecar
kubectl apply -f samples/httpbin/httpbin.yaml -n legacy
kubectl apply -f samples/sleep/sleep.yaml -n legacy
```

> 注：如果没有 samples 目录，可以从 Istio 官方仓库下载，或使用简单的 nginx/curl 镜像替代。

**步骤 2：测试默认连通性**

```bash
# 测试所有组合的连通性
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done
```

**预期结果**（默认 PERMISSIVE 模式）：
```
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.foo to httpbin.legacy: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.bar to httpbin.legacy: 200
sleep.legacy to httpbin.foo: 200    # legacy 也能访问
sleep.legacy to httpbin.bar: 200
sleep.legacy to httpbin.legacy: 200
```


**步骤 3：启用全局 STRICT 模式**

```bash
# 全局启用 STRICT mTLS
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system  # 全局生效
spec:
  mtls:
    mode: STRICT
EOF
```

**步骤 4：再次测试连通性**

```bash
# 再次测试
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done
```

**预期结果**（STRICT 模式）：
```
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.foo to httpbin.legacy: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.bar to httpbin.legacy: 200
sleep.legacy to httpbin.foo: 000    # 失败！legacy 没有证书
sleep.legacy to httpbin.bar: 000    # 失败！
sleep.legacy to httpbin.legacy: 200 # legacy 之间不走 mTLS
```

**关键发现**：legacy（没有 Sidecar）无法访问 foo 和 bar（有 Sidecar），因为它没有证书！

**步骤 5：为特定服务禁用 mTLS（可选）**

```bash
# 为 foo 命名空间的 httpbin 禁用 mTLS
cat <<EOF | kubectl apply -n foo -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: overwrite-example
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: DISABLE
EOF

# 再次测试
kubectl exec "$(kubectl get pod -l app=sleep -n legacy -o jsonpath={.items..metadata.name})" \
  -c sleep -n legacy -- curl -s "http://httpbin.foo:8000/ip" \
  -o /dev/null -w "sleep.legacy to httpbin.foo: %{http_code}\n"
# 现在应该返回 200
```

**步骤 6：验证 mTLS 是否生效**

```bash
# 查看请求头，确认 mTLS 生效
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers

# 输出中应该包含 X-Forwarded-Client-Cert，表示 mTLS 生效
```

**清理**：

```bash
kubectl delete peerauthentication default -n istio-system
kubectl delete peerauthentication overwrite-example -n foo
```

---


## 六、AuthorizationPolicy 访问控制

### 6.1 核心概念

AuthorizationPolicy 定义"谁能访问谁"，就像公司的门禁系统。

**生活比喻**：
- **PeerAuthentication** = 验证你是公司员工（身份认证）
- **AuthorizationPolicy** = 决定你能进哪些房间（访问控制）

**两种策略**：

| 策略 | 说明 | 用法 |
|------|------|------|
| **ALLOW** | 白名单，只允许指定的访问 | 默认拒绝，显式允许 |
| **DENY** | 黑名单，拒绝指定的访问 | 默认允许，显式拒绝 |

### 6.2 🔬 实验：访问控制

**步骤 1：创建默认拒绝策略**

```bash
# 在 foo 命名空间创建"拒绝所有"策略
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: foo
spec:
  {}  # 空规则 = 拒绝所有
EOF
```

**步骤 2：测试访问**

```bash
# 从 bar.sleep 访问 foo.httpbin（应该失败）
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/headers
# 输出：RBAC: access denied

# 从 foo.sleep 访问 foo.httpbin（也应该失败）
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers
# 输出：RBAC: access denied
```

**步骤 3：允许 GET 请求**

```bash
# 允许所有人用 GET 方法访问 httpbin
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-viewer
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["GET"]
EOF
```

**步骤 4：再次测试**

```bash
# 现在 GET 请求应该成功
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/headers
# 成功！

# POST 请求应该失败
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s -X POST http://httpbin.foo:8000/post
# 输出：RBAC: access denied
```

**步骤 5：限制只有特定服务能访问**

```bash
# 只允许 bar.sleep 访问 foo.httpbin
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-viewer
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/bar/sa/sleep"]  # 只允许 bar 命名空间的 sleep
    to:
    - operation:
        methods: ["GET"]
EOF
```

**步骤 6：验证精细控制**

```bash
# bar.sleep 可以访问
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/headers
# 成功！

# foo.sleep 不能访问
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers
# 输出：RBAC: access denied
```

**清理**：

```bash
kubectl delete authorizationpolicy allow-nothing -n foo
kubectl delete authorizationpolicy httpbin-viewer -n foo
```

---


## 七、分布式追踪

### 7.1 核心概念

分布式追踪让你看到一个请求经过了哪些服务，每个服务花了多长时间。

**生活比喻**：
- 就像快递追踪：你能看到包裹从发货、到分拣中心、到配送站、到你手上的全过程
- 每一站花了多长时间，一目了然

```
用户请求 → Gateway → Service A → Service B → Service C
              │          │           │           │
              ↓          ↓           ↓           ↓
           10ms       50ms        30ms        20ms
           
总耗时：110ms
瓶颈：Service A（50ms）
```

### 7.2 🔬 实验：Jaeger 分布式追踪

**步骤 1：安装 Jaeger**

```bash
# 安装 Jaeger
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# 或者使用本地文件
# kubectl apply -f jaeger.yaml

# 配置采样率（可选，默认 1%）
kubectl edit configmap istio -n istio-system
# 设置 tracing.sampling=100（100% 采样，仅用于测试）
```

**步骤 2：部署多层服务**

```bash
# 创建命名空间
kubectl create ns tracing
kubectl label ns tracing istio-injection=enabled

# 部署三层服务
cat <<EOF | kubectl apply -n tracing -f -
# Service 0 - 入口服务
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service0
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service0
  template:
    metadata:
      labels:
        app: service0
    spec:
      containers:
      - name: service0
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service0
spec:
  selector:
    app: service0
  ports:
  - port: 80
---
# Service 1 - 中间服务
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service1
  template:
    metadata:
      labels:
        app: service1
    spec:
      containers:
      - name: service1
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service1
spec:
  selector:
    app: service1
  ports:
  - port: 80
---
# Service 2 - 后端服务
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service2
  template:
    metadata:
      labels:
        app: service2
    spec:
      containers:
      - name: service2
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service2
spec:
  selector:
    app: service2
  ports:
  - port: 80
EOF

# 配置 Gateway 和路由
cat <<EOF | kubectl apply -n tracing -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: tracing-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - "*"
      port:
        name: http
        number: 80
        protocol: HTTP
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tracing-vs
spec:
  gateways:
    - tracing-gateway
  hosts:
    - "*"
  http:
    - match:
        - uri:
            prefix: /service0
      route:
        - destination:
            host: service0
            port:
              number: 80
EOF
```

**步骤 3：生成流量**

```bash
# 获取 Ingress IP
export INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 生成一些流量
for i in {1..100}; do
  curl -s http://$INGRESS_IP/service0 > /dev/null
done
```

**步骤 4：查看追踪**

```bash
# 打开 Jaeger Dashboard
istioctl dashboard jaeger

# 或者端口转发
kubectl port-forward -n istio-system svc/tracing 16686:80
# 然后访问 http://localhost:16686
```

**在 Jaeger UI 中**：
1. 选择 Service：`service0.tracing`
2. 点击 "Find Traces"
3. 查看请求链路和耗时

---


## 八、常用命令速查

### istioctl 诊断命令

```bash
# 查看 Pod 的 Istio 配置
istioctl x describe pod <pod-name>

# 分析配置问题
istioctl analyze

# 查看 Envoy 配置
istioctl pc listener <pod> -n <namespace>
istioctl pc route <pod> -n <namespace>
istioctl pc cluster <pod> -n <namespace>
istioctl pc endpoint <pod> -n <namespace>
istioctl pc secret <pod> -n <namespace>

# 打开 Dashboard
istioctl dashboard kiali
istioctl dashboard jaeger
istioctl dashboard grafana
istioctl dashboard prometheus
```

### 资源查看命令

```bash
# 查看所有 Istio 资源
kubectl get gateway -A
kubectl get virtualservice -A
kubectl get destinationrule -A
kubectl get peerauthentication -A
kubectl get authorizationpolicy -A

# 查看 Sidecar 日志
kubectl logs <pod> -c istio-proxy -f

# 查看 Sidecar 配置
kubectl exec <pod> -c istio-proxy -- pilot-agent request GET config_dump
```

---

## 九、核心要点总结

### 架构层面

| 组件 | 作用 | 类比 |
|------|------|------|
| Istiod | 控制平面，管理配置和证书 | 交通指挥中心 |
| Envoy Sidecar | 数据平面，拦截和转发流量 | 每辆车的导航仪 |
| Gateway | 入口网关，管理进出流量 | 机场航站楼 |

### 流量管理

| 资源 | 作用 | 类比 |
|------|------|------|
| VirtualService | 定义路由规则 | 红绿灯 |
| DestinationRule | 定义目的地策略 | 路标 |
| Gateway | 定义入口规则 | 大门 |

### 安全管理

| 资源 | 作用 | 类比 |
|------|------|------|
| mTLS | 服务间加密通信 | 加密电话 |
| PeerAuthentication | 定义 mTLS 模式 | 门禁系统 |
| AuthorizationPolicy | 定义访问控制 | 权限管理 |

### 最佳实践

1. **渐进式启用 mTLS**：先 PERMISSIVE，再 STRICT
2. **最小权限原则**：默认拒绝，显式允许
3. **灰度发布**：先小流量验证，再逐步扩大
4. **故障注入**：定期演练，提高系统健壮性
5. **监控追踪**：开启 Jaeger，及时发现问题

---

## 十、实验清理

```bash
# 清理所有实验资源
kubectl delete ns sidecar
kubectl delete ns simple
kubectl delete ns securesvc
kubectl delete ns canary
kubectl delete ns foo
kubectl delete ns bar
kubectl delete ns legacy
kubectl delete ns tracing

# 清理全局配置
kubectl delete peerauthentication default -n istio-system --ignore-not-found
```

---

## 参考资料

- [Istio 官方文档](https://istio.io/latest/docs/)
- [Envoy 官方文档](https://www.envoyproxy.io/docs/)
- 极客时间云原生训练营 - 模块 12、14

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-16
- 基于 Istio 版本：1.20+
- 适用对象：有 Kubernetes 基础的开发者

---

> 💡 **学习建议**：不要只看文档，一定要动手做实验！理论 + 实践 = 真正掌握。
