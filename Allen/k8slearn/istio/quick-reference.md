# Istio 快速参考手册

> 常用命令和配置速查

## 一、安装和管理

### 安装 Istio
```bash
# 下载 Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# 安装（demo profile）
istioctl install --set profile=demo -y

# 安装（default profile）
istioctl install --set profile=default -y

# 启用访问日志
istioctl install --set profile=demo \
  --set meshConfig.accessLogFile=/dev/stdout -y
```

### 卸载 Istio
```bash
# 卸载 Istio
istioctl uninstall --purge -y

# 删除命名空间
kubectl delete namespace istio-system
```

### 版本管理
```bash
# 查看版本
istioctl version

# 升级 Istio
istioctl upgrade
```

---

## 二、Sidecar 管理

### 自动注入
```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 禁用自动注入
kubectl label namespace default istio-injection-

# 查看标签
kubectl get namespace -L istio-injection
```

### 手动注入
```bash
# 手动注入 Sidecar
istioctl kube-inject -f deployment.yaml | kubectl apply -f -

# 或者
kubectl apply -f <(istioctl kube-inject -f deployment.yaml)
```

### 验证注入
```bash
# 查看 Pod 容器数量（应该是 2）
kubectl get pods

# 查看 Sidecar 日志
kubectl logs <pod-name> -c istio-proxy
```

---

## 三、流量管理

### VirtualService 示例

**基础路由**
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
        subset: v1
```

**按权重分流（灰度发布）**
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
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
```

**基于请求头路由**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

**超时和重试**
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
        subset: v1
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 2s
```

**故障注入**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 10
        fixedDelay: 5s
    route:
    - destination:
        host: ratings
        subset: v1
```

### DestinationRule 示例

**定义 Subset**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

**负载均衡**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN  # 轮询
      # simple: LEAST_CONN  # 最少连接
      # simple: RANDOM      # 随机
```

**熔断器**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 1
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

### Gateway 示例

**HTTP Gateway**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

**HTTPS Gateway**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: bookinfo-credential
    hosts:
    - "bookinfo.example.com"
```

---

## 四、安全管理

### PeerAuthentication 示例

**全局启用 STRICT mTLS**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

**命名空间级别**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: foo
spec:
  mtls:
    mode: STRICT
```

**服务级别**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
```

**端口级别**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: httpbin
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: DISABLE
```

### AuthorizationPolicy 示例

**拒绝所有**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: foo
spec:
  {}
```

**允许所有**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-all
  namespace: foo
spec:
  action: ALLOW
  rules:
  - {}
```

**基于来源的访问控制**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/sleep"]
```

**基于操作的访问控制**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
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
        paths: ["/info*"]
```

---

## 五、诊断命令

### 分析和状态
```bash
# 分析配置问题
istioctl analyze
istioctl analyze --namespace default
istioctl analyze --all-namespaces

# 查看代理状态
istioctl proxy-status
istioctl proxy-status <pod-name>
```

### 代理配置
```bash
# 查看路由配置
istioctl proxy-config routes <pod-name>

# 查看 cluster 配置
istioctl proxy-config clusters <pod-name>

# 查看 listener 配置
istioctl proxy-config listeners <pod-name>

# 查看 endpoint 配置
istioctl proxy-config endpoints <pod-name>

# 查看所有配置
istioctl proxy-config all <pod-name>
```

### mTLS 检查
```bash
# 检查 mTLS 状态
istioctl authn tls-check <pod-name>
istioctl authn tls-check <pod-name> <service-name>
```

### 日志查看
```bash
# 查看应用日志
kubectl logs <pod-name> -c <container-name>

# 查看 Sidecar 日志
kubectl logs <pod-name> -c istio-proxy

# 查看 Sidecar 日志（实时）
kubectl logs <pod-name> -c istio-proxy -f

# 查看 istio-init 日志
kubectl logs <pod-name> -c istio-init
```

---

## 六、常用 kubectl 命令

### 查看资源
```bash
# 查看 VirtualService
kubectl get virtualservice
kubectl get vs

# 查看 DestinationRule
kubectl get destinationrule
kubectl get dr

# 查看 Gateway
kubectl get gateway
kubectl get gw

# 查看 PeerAuthentication
kubectl get peerauthentication
kubectl get pa

# 查看 AuthorizationPolicy
kubectl get authorizationpolicy
kubectl get ap

# 查看所有 Istio 资源
kubectl get vs,dr,gw,pa,ap --all-namespaces
```

### 查看详情
```bash
# 查看资源详情
kubectl describe virtualservice <name>
kubectl describe destinationrule <name>

# 查看 YAML
kubectl get virtualservice <name> -o yaml
kubectl get destinationrule <name> -o yaml
```

### 删除资源
```bash
# 删除 VirtualService
kubectl delete virtualservice <name>

# 删除 DestinationRule
kubectl delete destinationrule <name>

# 删除所有 VirtualService
kubectl delete virtualservice --all
```

---

## 七、BookInfo 示例

### 部署 BookInfo
```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 部署应用
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# 部署 Gateway
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

# 部署 DestinationRule
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

### 流量管理示例
```bash
# 所有流量到 v1
kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml

# reviews v2 for user jason
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml

# 50% v1, 50% v3
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml

# 故障注入
kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
```

### 清理 BookInfo
```bash
# 删除路由规则
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml

# 删除 DestinationRule
kubectl delete -f samples/bookinfo/networking/destination-rule-all.yaml

# 删除 Gateway
kubectl delete -f samples/bookinfo/networking/bookinfo-gateway.yaml

# 删除应用
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml
```

---

## 八、常见问题速查

| 问题 | 排查命令 | 解决方案 |
|------|---------|---------|
| Sidecar 没注入 | `kubectl get pods` | 启用自动注入并重启 Pod |
| 路由不生效 | `istioctl analyze` | 检查 VirtualService 和 DestinationRule |
| mTLS 连接失败 | `istioctl authn tls-check` | 统一 PeerAuthentication 模式 |
| Pod 启动失败 | `kubectl describe pod` | 检查日志和资源 |
| 访问日志没有 | `kubectl logs -c istio-proxy` | 启用 accessLogFile |

---

## 九、性能调优

### Sidecar 资源限制
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    sidecar.istio.io/proxyCPU: "100m"
    sidecar.istio.io/proxyMemory: "128Mi"
    sidecar.istio.io/proxyCPULimit: "2000m"
    sidecar.istio.io/proxyMemoryLimit: "1024Mi"
```

### 禁用 Sidecar
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

### 限制 Sidecar 范围
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: default
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

---

## 十、金句收藏

```
"VirtualService 是红绿灯，DestinationRule 是路标"

"mTLS 就像给服务发身份证，持证上岗"

"istioctl analyze 是你的第一道防线"

"Sidecar 没注入，一切都是空谈"

"日志是你的好朋友，不看日志就排查，那是瞎猜"
```

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-08
- 基于 Istio 版本：1.20+
- 适用对象：Istio 用户
