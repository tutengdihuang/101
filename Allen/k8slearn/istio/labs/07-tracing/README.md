# 实验七：分布式追踪

> 使用 Jaeger 追踪请求在服务间的流转

## 实验目标

- 理解分布式追踪的原理
- 掌握 Jaeger 的使用
- 学会分析调用链

## 架构图

```
外部请求 → service0 → service1 → service2
              ↓           ↓          ↓
           Jaeger ←── 追踪数据 ──────┘
```

## 实验步骤

### 1. 安装 Jaeger

```bash
kubectl apply -f jaeger.yaml
```

### 2. 配置采样率

```bash
# 编辑 Istio 配置，设置采样率为 100%
kubectl edit configmap istio -n istio-system
# 设置 tracing.sampling=100
```

### 3. 部署测试服务

```bash
kubectl create ns tracing
kubectl label ns tracing istio-injection=enabled
kubectl apply -f service0.yaml -n tracing
kubectl apply -f service1.yaml -n tracing
kubectl apply -f service2.yaml -n tracing
kubectl apply -f istio-specs.yaml -n tracing
```

### 4. 发送测试请求

```bash
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 发送多次请求
for i in {1..10}; do
    curl $INGRESS_IP/service0
done
```

### 5. 查看追踪数据

```bash
# 打开 Jaeger Dashboard
istioctl dashboard jaeger
```

## 核心配置

### Gateway + VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: service0
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - '*'
    port:
      name: http-service0
      number: 80
      protocol: HTTP
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: service0
spec:
  gateways:
  - service0
  hosts:
  - '*'
  http:
  - match:
    - uri:
        exact: /service0
    route:
    - destination:
        host: service0
        port:
          number: 80
```

## 追踪原理

Istio 通过 Envoy Sidecar 自动收集追踪数据：

1. **Span**：一次服务调用
2. **Trace**：一个完整的请求链路
3. **Context Propagation**：追踪上下文传递

### 追踪 Header

```
x-request-id
x-b3-traceid
x-b3-spanid
x-b3-parentspanid
x-b3-sampled
x-b3-flags
```

## 采样率配置

```yaml
# 在 istio configmap 中配置
tracing:
  sampling: 100  # 100% 采样
```

生产环境建议：1-10%

## 清理

```bash
kubectl delete ns tracing
kubectl delete -f jaeger.yaml
```
