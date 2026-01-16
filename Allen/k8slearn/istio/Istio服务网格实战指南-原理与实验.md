# Istio 服务网格实战指南：原理与实验

> 动手党专属：每个原理都有实验验证，眼见为实

## 前言

如果你已经看过 Istio 的基础概念，现在想动手实践，这篇文章就是为你准备的。

本文的特点是：**每讲一个原理，就做一个实验**。不是干巴巴地讲理论，而是让你亲眼看到 Istio 是怎么工作的。

**本文假设你已经**：
- 有一个运行中的 Kubernetes 集群
- 已经安装了 Istio（推荐 demo profile）
- 了解 Istio 的基本概念（如果不了解，先看《Istio 服务网格完全指南》）

**本文将带你实验**：
1. Sidecar 流量劫持的底层原理
2. 灰度发布与金丝雀部署
3. 故障注入与容错测试
4. mTLS 加密通信
5. 服务间访问控制
6. 分布式追踪

准备好了吗？让我们开始动手！

---

## 目录

1. [实验一：Sidecar 流量劫持原理](#实验一sidecar-流量劫持原理)
2. [实验二：灰度发布与金丝雀部署](#实验二灰度发布与金丝雀部署)
3. [实验三：故障注入与容错测试](#实验三故障注入与容错测试)
4. [实验四：mTLS 加密通信](#实验四mtls-加密通信)
5. [实验五：服务间访问控制](#实验五服务间访问控制)
6. [实验六：分布式追踪](#实验六分布式追踪)
7. [常用命令速查](#常用命令速查)

---

## 实验一：Sidecar 流量劫持原理

### 原理讲解

Sidecar 是 Istio 的灵魂。它像一个"隐形保镖"，被注入到每个 Pod 中，拦截所有进出的流量。

**但它是怎么做到的？** 答案是 **iptables**。


想象你住在一个高档小区：
- **没有 Sidecar**：你直接出门，没人知道你去哪、干什么
- **有 Sidecar**：门口有个保安（Envoy），所有进出都要经过他

Istio 用 iptables 规则强制所有流量经过 Envoy：

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

**关键端口**：
- **15001**：出站流量入口（你要出门）
- **15006**：入站流量入口（有人来找你）

**流量路径**：
```
出站：应用发请求 → iptables 劫持到 15001 → Envoy 处理 → 发送到目标
入站：请求到达 Pod → iptables 劫持到 15006 → Envoy 处理 → 转发给应用
```

### 动手实验

**步骤 1：创建实验环境**

```bash
# 创建命名空间并启用 Sidecar 注入
kubectl create ns sidecar
kubectl label ns sidecar istio-injection=enabled
```

**实验输出**：
```
$ kubectl create ns sidecar
namespace/sidecar created

$ kubectl label ns sidecar istio-injection=enabled
namespace/sidecar labeled
```

**步骤 2：部署测试应用**

```bash
# 部署 nginx
cat <<EOF | kubectl apply -n sidecar -f -
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
EOF

# 部署 toolbox（用于测试）
cat <<EOF | kubectl apply -n sidecar -f -
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

**实验输出**：
```
$ kubectl get pods -n sidecar
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6799fc88d8-xxxxx   2/2     Running   0          30s
toolbox-68f79dd5f8-xxxxx            2/2     Running   0          30s
```

注意 `READY` 列是 `2/2`，说明每个 Pod 都有 2 个容器：应用 + Sidecar。

**步骤 3：查看 Envoy 配置**

```bash
# 获取 toolbox Pod 名称
POD=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')

# 查看 Listener（监听器）
istioctl pc listener -n sidecar $POD
```

**实验输出**：
```
$ istioctl pc listener -n sidecar $POD
ADDRESS        PORT  MATCH                                                          DESTINATION
10.96.0.1      443   ALL                                                            Cluster: outbound|443||kubernetes.default.svc.cluster.local
10.96.0.10     53    ALL                                                            Cluster: outbound|53||kube-dns.kube-system.svc.cluster.local
0.0.0.0        80    Trans: raw_buffer; App: http/1.1,h2c                           Route: 80
0.0.0.0        15001 ALL                                                            PassthroughCluster
0.0.0.0        15006 Trans: tls; App: istio-http/1.0,istio-http/1.1,istio-h2        InboundPassthroughClusterIpv4
0.0.0.0        15006 Trans: raw_buffer; App: http/1.1,h2c                           InboundPassthroughClusterIpv4
0.0.0.0        15006 Trans: tls; App: TCP TLS                                       InboundPassthroughClusterIpv4
0.0.0.0        15006 Trans: raw_buffer                                              InboundPassthroughClusterIpv4
0.0.0.0        15006 Trans: tls                                                     InboundPassthroughClusterIpv4
0.0.0.0        15090 ALL                                                            Inline Route: /stats/prometheus*
```

看到了吗？15001 和 15006 就是我们说的出站和入站端口！


**步骤 4：追踪流量路径**

```bash
# 查看 Route（路由规则）
istioctl pc route -n sidecar $POD --name=80
```

**实验输出**：
```
$ istioctl pc route -n sidecar $POD --name=80
NAME     DOMAINS                                    MATCH     VIRTUAL SERVICE
80       nginx.sidecar.svc.cluster.local            /*        
80       nginx.sidecar.svc.cluster.local:80         /*        
80       nginx.sidecar                              /*        
80       nginx.sidecar:80                           /*        
80       nginx                                      /*        
80       nginx:80                                   /*        
```

Envoy 知道 `nginx` 这个服务名对应哪个 Cluster。

```bash
# 查看 Cluster（上游服务）
istioctl pc cluster -n sidecar $POD | grep nginx
```

**实验输出**：
```
$ istioctl pc cluster -n sidecar $POD | grep nginx
nginx.sidecar.svc.cluster.local                    80        -          outbound      EDS
```

```bash
# 查看 Endpoint（具体的 Pod IP）
istioctl pc endpoint -n sidecar $POD | grep nginx
```

**实验输出**：
```
$ istioctl pc endpoint -n sidecar $POD | grep nginx
192.168.166.189:80    HEALTHY     OK    outbound|80||nginx.sidecar.svc.cluster.local
```

**完整的流量路径**：
```
toolbox 发起 curl nginx
    ↓
iptables 劫持到 15001（virtualOutbound）
    ↓
Envoy 查找 Listener 0.0.0.0_80
    ↓
Envoy 查找 Route 80，匹配到 nginx.sidecar.svc.cluster.local
    ↓
Envoy 查找 Cluster outbound|80||nginx.sidecar.svc.cluster.local
    ↓
Envoy 查找 Endpoint 192.168.166.189:80
    ↓
请求发送到 nginx Pod
```

**步骤 5：验证流量确实经过 Sidecar**

```bash
# 从 toolbox 访问 nginx
kubectl exec -it $POD -n sidecar -c toolbox -- curl -s nginx

# 查看 Sidecar 日志
kubectl logs $POD -n sidecar -c istio-proxy --tail=5
```

**实验输出**：
```
$ kubectl logs $POD -n sidecar -c istio-proxy --tail=5
[2026-01-16T10:30:45.123Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 615 3 2 "-" "curl/7.61.1" "xxx" "nginx:80" "192.168.166.189:80" outbound|80||nginx.sidecar.svc.cluster.local 192.168.166.188:45678 10.96.100.100:80 192.168.166.188:12345 - default
```

日志显示请求经过了 Sidecar，目标是 `outbound|80||nginx.sidecar.svc.cluster.local`。

### 实验小结

通过这个实验，你亲眼看到了：
1. Sidecar 通过 iptables 劫持流量
2. Envoy 的配置结构：Listener → Route → Cluster → Endpoint
3. 流量确实经过了 Sidecar（从日志可以看到）

---

## 实验二：灰度发布与金丝雀部署

### 原理讲解

灰度发布就像"试吃"：新菜品先让少数顾客试吃，反馈好再推广给所有人。

**传统方式 vs Istio 方式**：

| 方面 | 传统方式 | Istio 方式 |
|------|---------|-----------|
| 实现 | 改代码、改配置、重新部署 | 改 YAML 配置 |
| 生效 | 分钟级（重新部署） | 秒级（配置下发） |
| 回滚 | 再次部署 | 改配置即可 |
| 粒度 | 粗粒度 | 可按 Header、用户等精细控制 |

**两种灰度策略**：

1. **按比例分流**：90% 流量走 v1，10% 流量走 v2
2. **按条件分流**：特定用户走 v2，其他用户走 v1

### 动手实验

**步骤 1：创建实验环境**

```bash
kubectl create ns canary
kubectl label ns canary istio-injection=enabled
```

**步骤 2：部署 v1 版本**

```bash
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
          echo "=== Version 1 ===" > /usr/share/nginx/html/hello
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
```

**步骤 3：部署 toolbox**

```bash
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

**步骤 4：测试 v1**

```bash
TOOLBOX=$(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
```

**实验输出**：
```
$ kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
=== Version 1 ===
```


**步骤 5：部署 v2 版本**

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
          echo "=== Version 2 - NEW! ===" > /usr/share/nginx/html/hello
          nginx -g "daemon off;"
EOF
```

**步骤 6：观察默认行为**

现在有两个版本同时运行，但没有配置路由规则。多次访问看看：

```bash
for i in {1..6}; do
  echo "请求 $i:"
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
done
```

**实验输出**：
```
$ for i in {1..6}; do echo "请求 $i:"; kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello; done
请求 1:
=== Version 1 ===
请求 2:
=== Version 2 - NEW! ===
请求 3:
=== Version 1 ===
请求 4:
=== Version 2 - NEW! ===
请求 5:
=== Version 1 ===
请求 6:
=== Version 2 - NEW! ===
```

流量随机分配到两个版本——这不是我们想要的！

**步骤 7：配置基于 Header 的路由**

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
              exact: jesse    # 如果 Header 包含 user: jesse
      route:
        - destination:
            host: canary
            subset: v2        # 走 v2
    - route:
        - destination:
            host: canary
            subset: v1        # 其他走 v1
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: canary
spec:
  host: canary
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

**步骤 8：验证路由规则**

```bash
# 普通请求 → v1
echo "=== 普通请求 ==="
for i in {1..3}; do
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
done

# 带 Header 的请求 → v2
echo "=== VIP 请求 (user: jesse) ==="
for i in {1..3}; do
  kubectl exec -it $TOOLBOX -n canary -- curl -s -H "user: jesse" canary/hello
done
```

**实验输出**：
```
$ echo "=== 普通请求 ===" && for i in {1..3}; do kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello; done
=== 普通请求 ===
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===

$ echo "=== VIP 请求 (user: jesse) ===" && for i in {1..3}; do kubectl exec -it $TOOLBOX -n canary -- curl -s -H "user: jesse" canary/hello; done
=== VIP 请求 (user: jesse) ===
=== Version 2 - NEW! ===
=== Version 2 - NEW! ===
=== Version 2 - NEW! ===
```

完美！普通用户走 v1，VIP 用户（jesse）走 v2。

**步骤 9：配置按比例分流**

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
          weight: 90    # 90% 走 v1
        - destination:
            host: canary
            subset: v2
          weight: 10    # 10% 走 v2
EOF
```

```bash
# 测试 10 次，大约 9 次 v1，1 次 v2
for i in {1..10}; do
  kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
done
```

**实验输出**：
```
$ for i in {1..10}; do kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello; done
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===
=== Version 2 - NEW! ===
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===
=== Version 1 ===
```

大约 10% 的流量走了 v2，符合预期！

### 实验小结

通过这个实验，你学会了：
1. **基于 Header 的路由**：特定用户走新版本
2. **按比例分流**：90-10 灰度发布
3. **秒级生效**：改配置立即生效，不需要重新部署

---

## 实验三：故障注入与容错测试

### 原理讲解

故障注入就像"消防演习"：在可控环境下模拟故障，看系统会不会崩溃。

**两种故障类型**：

| 类型 | 说明 | 用途 |
|------|------|------|
| **延迟注入** | 人为增加响应时间 | 测试超时处理 |
| **错误注入** | 人为返回错误码 | 测试错误处理 |

**为什么要做故障注入？**

- 发现系统的薄弱环节
- 验证应急预案是否有效
- 在生产环境出问题之前发现问题

### 动手实验

我们继续使用 canary 命名空间。

**步骤 1：注入 5 秒延迟**

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
    - fault:
        delay:
          percentage:
            value: 100    # 100% 的请求
          fixedDelay: 5s  # 延迟 5 秒
      route:
        - destination:
            host: canary
            subset: v1
EOF
```

**步骤 2：测试延迟**

```bash
echo "开始时间: $(date +%H:%M:%S)"
kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello
echo "结束时间: $(date +%H:%M:%S)"
```

**实验输出**：
```
$ echo "开始时间: $(date +%H:%M:%S)" && kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello && echo "结束时间: $(date +%H:%M:%S)"
开始时间: 10:35:20
=== Version 1 ===
结束时间: 10:35:25
```

请求花了 5 秒！延迟注入成功。


**步骤 3：注入 50% 的 500 错误**

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
    - fault:
        abort:
          percentage:
            value: 50     # 50% 的请求
          httpStatus: 500 # 返回 500 错误
      route:
        - destination:
            host: canary
            subset: v1
EOF
```

**步骤 4：测试错误注入**

```bash
for i in {1..10}; do
  echo -n "请求 $i: "
  kubectl exec -it $TOOLBOX -n canary -- curl -s -o /dev/null -w "%{http_code}" canary/hello
  echo ""
done
```

**实验输出**：
```
$ for i in {1..10}; do echo -n "请求 $i: "; kubectl exec -it $TOOLBOX -n canary -- curl -s -o /dev/null -w "%{http_code}" canary/hello; echo ""; done
请求 1: 200
请求 2: 500
请求 3: 200
请求 4: 500
请求 5: 500
请求 6: 200
请求 7: 500
请求 8: 200
请求 9: 500
请求 10: 200
```

大约 50% 的请求返回了 500 错误！

**步骤 5：配置超时和重试**

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
      timeout: 3s           # 超时 3 秒
      retries:
        attempts: 3         # 重试 3 次
        perTryTimeout: 1s   # 每次重试超时 1 秒
        retryOn: 5xx        # 遇到 5xx 错误时重试
EOF
```

这个配置的意思是：
- 如果请求超过 3 秒没响应，就超时
- 如果遇到 500 错误，自动重试，最多重试 3 次

**步骤 6：清理故障注入**

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

### 实验小结

通过这个实验，你学会了：
1. **延迟注入**：测试系统对慢响应的处理
2. **错误注入**：测试系统对错误的处理
3. **超时和重试**：提高系统的容错能力

---

## 实验四：mTLS 加密通信

### 原理讲解

mTLS（双向 TLS）让服务间的通信自动加密，而且双方都要验证身份。

**没有 mTLS**：
```
服务 A："喂，我是服务 A"
服务 B："好的，我是服务 B"
黑客："我在旁边偷听呢..."
```

**有 mTLS**：
```
服务 A："这是我的证书"
服务 B："验证通过，这是我的证书"
服务 A："验证通过，开始加密通话"
黑客："我听不懂他们在说什么..."
```

**三种模式**：

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **PERMISSIVE** | 接受 mTLS 和明文 | 迁移过渡期 |
| **STRICT** | 只接受 mTLS | 生产环境 |
| **DISABLE** | 禁用 mTLS | 特殊场景 |

### 动手实验

**步骤 1：创建测试环境**

```bash
# 创建三个命名空间
kubectl create ns foo
kubectl create ns bar
kubectl create ns legacy

# foo 和 bar 启用 Sidecar 注入
kubectl label ns foo istio-injection=enabled
kubectl label ns bar istio-injection=enabled
# legacy 不启用（模拟没有 Sidecar 的遗留系统）
```

**步骤 2：部署测试应用**

```bash
# 在 foo 和 bar 部署 httpbin 和 sleep（会自动注入 Sidecar）
cat <<EOF | kubectl apply -n foo -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - port: 8000
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      serviceAccountName: sleep
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sleep
EOF

# 在 bar 部署同样的应用
kubectl apply -n bar -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - port: 8000
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      serviceAccountName: sleep
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sleep
EOF

# 在 legacy 部署（不会注入 Sidecar）
kubectl apply -n legacy -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
EOF
```


**步骤 3：测试默认连通性**

```bash
# 测试所有组合
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done
```

**实验输出**（默认 PERMISSIVE 模式）：
```
$ for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 200    # legacy 也能访问！
sleep.legacy to httpbin.bar: 200
```

所有请求都成功了，包括没有 Sidecar 的 legacy。

**步骤 4：启用全局 STRICT 模式**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
```

**步骤 5：再次测试连通性**

```bash
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n" 2>/dev/null || echo "sleep.${from} to httpbin.${to}: FAILED"
  done
done
```

**实验输出**（STRICT 模式）：
```
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: FAILED    # 失败！
sleep.legacy to httpbin.bar: FAILED    # 失败！
```

**关键发现**：legacy（没有 Sidecar）无法访问 foo 和 bar 了！因为它没有证书，无法建立 mTLS 连接。

**步骤 6：验证 mTLS 确实生效**

```bash
# 查看请求头，确认 mTLS 生效
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers | grep -i x-forwarded-client-cert
```

**实验输出**：
```
$ kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers | grep -i x-forwarded-client-cert
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/foo/sa/default;Hash=xxx;Subject=\"\";URI=spiffe://cluster.local/ns/foo/sa/sleep"
```

看到 `X-Forwarded-Client-Cert` 了吗？这说明 mTLS 确实生效了，请求携带了客户端证书。

**步骤 7：清理**

```bash
kubectl delete peerauthentication default -n istio-system
```

### 实验小结

通过这个实验，你学会了：
1. **PERMISSIVE 模式**：接受 mTLS 和明文，适合过渡期
2. **STRICT 模式**：只接受 mTLS，没有证书的服务无法访问
3. **验证 mTLS**：通过 `X-Forwarded-Client-Cert` 头确认

---

## 实验五：服务间访问控制

### 原理讲解

AuthorizationPolicy 定义"谁能访问谁"，就像公司的门禁系统。

- **PeerAuthentication** 验证你是谁（身份认证）
- **AuthorizationPolicy** 决定你能去哪（访问控制）

**两种策略**：
- **ALLOW**：白名单，只允许指定的访问
- **DENY**：黑名单，拒绝指定的访问

### 动手实验

我们继续使用 foo 和 bar 命名空间。

**步骤 1：创建默认拒绝策略**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: foo
spec:
  {}    # 空规则 = 拒绝所有
EOF
```

**步骤 2：测试访问**

```bash
# 从 bar.sleep 访问 foo.httpbin
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/ip
```

**实验输出**：
```
$ kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" -c sleep -n bar -- curl -s http://httpbin.foo:8000/ip
RBAC: access denied
```

访问被拒绝了！

**步骤 3：允许 GET 请求**

```bash
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
        methods: ["GET"]    # 只允许 GET 方法
EOF
```

**步骤 4：测试 GET 和 POST**

```bash
# GET 请求应该成功
echo "=== GET 请求 ==="
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/ip

# POST 请求应该失败
echo "=== POST 请求 ==="
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s -X POST http://httpbin.foo:8000/post
```

**实验输出**：
```
=== GET 请求 ===
{
  "origin": "192.168.166.188"
}
=== POST 请求 ===
RBAC: access denied
```

GET 成功，POST 被拒绝！


**步骤 5：限制只有特定服务能访问**

```bash
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
        principals: ["cluster.local/ns/bar/sa/sleep"]    # 只允许 bar 命名空间的 sleep
    to:
    - operation:
        methods: ["GET"]
EOF
```

**步骤 6：测试精细控制**

```bash
# bar.sleep 可以访问
echo "=== bar.sleep 访问 ==="
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl -s http://httpbin.foo:8000/ip

# foo.sleep 不能访问
echo "=== foo.sleep 访问 ==="
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/ip
```

**实验输出**：
```
=== bar.sleep 访问 ===
{
  "origin": "192.168.166.188"
}
=== foo.sleep 访问 ===
RBAC: access denied
```

只有 bar.sleep 能访问，foo.sleep 被拒绝了！

**步骤 7：清理**

```bash
kubectl delete authorizationpolicy allow-nothing -n foo
kubectl delete authorizationpolicy httpbin-viewer -n foo
```

### 实验小结

通过这个实验，你学会了：
1. **默认拒绝**：空规则 = 拒绝所有
2. **按方法控制**：只允许 GET，拒绝 POST
3. **按来源控制**：只允许特定服务访问

---

## 实验六：分布式追踪

### 原理讲解

分布式追踪让你看到一个请求经过了哪些服务，每个服务花了多长时间。

就像快递追踪：你能看到包裹从发货、到分拣中心、到配送站、到你手上的全过程。

```
用户请求 → Gateway → Service A → Service B → Service C
              │          │           │           │
              ↓          ↓           ↓           ↓
           10ms       50ms        30ms        20ms
           
总耗时：110ms
瓶颈：Service A（50ms）
```

### 动手实验

**步骤 1：安装 Jaeger**

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
```

**实验输出**：
```
$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
deployment.apps/jaeger created
service/tracing created
service/zipkin created
service/jaeger-collector created
```

**步骤 2：部署多层服务**

```bash
kubectl create ns tracing
kubectl label ns tracing istio-injection=enabled

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
# Service 1
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
EOF
```

**步骤 3：生成流量**

```bash
# 获取 Ingress IP
export INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 如果是 NodePort
if [ -z "$INGRESS_IP" ]; then
  export INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
  export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
  export INGRESS_IP="$INGRESS_IP:$INGRESS_PORT"
fi

# 生成流量（在集群内部测试）
TOOLBOX=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')
for i in {1..20}; do
  kubectl exec -it $TOOLBOX -n sidecar -- curl -s http://service0.tracing/
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

### 实验小结

通过这个实验，你学会了：
1. **安装 Jaeger**：Istio 的分布式追踪组件
2. **查看追踪**：通过 Jaeger UI 查看请求链路
3. **定位瓶颈**：找出哪个服务最慢

---

## 常用命令速查

### istioctl 诊断命令

```bash
# 查看 Pod 的 Istio 配置
istioctl x describe pod <pod-name>

# 分析配置问题
istioctl analyze

# 查看 Envoy 配置
istioctl pc listener <pod> -n <namespace>    # 监听器
istioctl pc route <pod> -n <namespace>       # 路由
istioctl pc cluster <pod> -n <namespace>     # 上游服务
istioctl pc endpoint <pod> -n <namespace>    # 端点

# 打开 Dashboard
istioctl dashboard kiali      # 服务拓扑
istioctl dashboard jaeger     # 分布式追踪
istioctl dashboard grafana    # 监控面板
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
```

---

## 实验清理

```bash
# 清理所有实验资源
kubectl delete ns sidecar
kubectl delete ns canary
kubectl delete ns foo
kubectl delete ns bar
kubectl delete ns legacy
kubectl delete ns tracing

# 清理全局配置
kubectl delete peerauthentication default -n istio-system --ignore-not-found
```

---

## 总结

通过这 6 个实验，你亲手验证了 Istio 的核心功能：

| 实验 | 学到了什么 |
|------|-----------|
| Sidecar 流量劫持 | iptables 劫持、Envoy 配置结构 |
| 灰度发布 | 按比例分流、按 Header 路由 |
| 故障注入 | 延迟注入、错误注入、超时重试 |
| mTLS | PERMISSIVE vs STRICT 模式 |
| 访问控制 | 默认拒绝、按方法/来源控制 |
| 分布式追踪 | Jaeger 安装和使用 |

**记住**：学 Istio 最好的方式就是动手做实验。理论看 100 遍，不如自己做 1 遍！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-16
- 基于 Istio 版本：1.20+
- 适用对象：有 Kubernetes 基础、想动手实践 Istio 的开发者

---

> 💡 **建议**：把这篇文章和《Istio 服务网格完全指南》配合看，一篇讲原理，一篇做实验，效果更好！
