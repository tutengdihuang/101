# 实验一：HTTP Gateway

> 通过 Istio Gateway 暴露服务到集群外部

## 实验目标

- 理解 Gateway 和 VirtualService 的关系
- 掌握 HTTP 流量的入口配置
- 学会通过 Host Header 访问服务

## 架构图

```
外部请求 → Istio IngressGateway → VirtualService → Service → Pod
              (端口 80)           (路由规则)      (ClusterIP)
```

## 实验步骤

### 1. 创建命名空间并启用 Sidecar 注入

```bash
kubectl create ns simple
kubectl label ns simple istio-injection=enabled
```

### 2. 部署应用

```bash
kubectl apply -f simple.yaml -n simple
```

### 3. 配置 Gateway 和 VirtualService

```bash
kubectl apply -f istio-specs.yaml -n simple
```

### 4. 获取 Ingress IP

```bash
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# 如果是 NodePort 模式
export INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
export INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
```

### 5. 测试访问

```bash
# 通过 Host Header 访问
curl -H "Host: simple.cncamp.io" $INGRESS_IP/hello -v

# 如果是 NodePort
curl -H "Host: simple.cncamp.io" $INGRESS_IP:$INGRESS_PORT/hello -v
```

## 核心配置解析

### Gateway - 定义入口

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: simple
spec:
  selector:
    istio: ingressgateway    # 选择 Istio 的 IngressGateway
  servers:
  - hosts:
    - simple.cncamp.io       # 接受的域名
    port:
      name: http-simple
      number: 80
      protocol: HTTP
```

### VirtualService - 定义路由

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: simple
spec:
  gateways:
  - simple                   # 关联到 Gateway
  hosts:
  - simple.cncamp.io         # 匹配的域名
  http:
  - match:
    - port: 80
    route:
    - destination:
        host: simple.simple.svc.cluster.local  # 目标服务
        port:
          number: 80
```

## 清理

```bash
kubectl delete ns simple
```

## 常见问题

**Q: 为什么要用 Host Header？**
A: Istio Gateway 通过 Host Header 区分不同的服务，类似于 Nginx 的虚拟主机。

**Q: Gateway 和 Kubernetes Ingress 有什么区别？**
A: Gateway 是 Istio 的 CRD，功能更强大，支持更细粒度的流量控制。
