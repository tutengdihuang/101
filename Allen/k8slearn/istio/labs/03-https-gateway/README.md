# 实验三：HTTPS Gateway

> 配置 TLS 终止，实现 HTTPS 访问

## 实验目标

- 掌握 TLS 证书的创建和管理
- 学会配置 HTTPS Gateway
- 理解 TLS 终止的工作原理

## 架构图

```
外部请求 (HTTPS) → Istio IngressGateway → 服务 (HTTP)
                   (TLS 终止)
```

## 实验步骤

### 1. 创建命名空间

```bash
kubectl create ns securesvc
kubectl label ns securesvc istio-injection=enabled
```

### 2. 部署应用

```bash
kubectl apply -f httpserver.yaml -n securesvc
```

### 3. 创建 TLS 证书

```bash
# 生成自签名证书
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=cncamp Inc./CN=*.cncamp.io' \
  -keyout cncamp.io.key \
  -out cncamp.io.crt

# 创建 Kubernetes Secret
kubectl create -n istio-system secret tls cncamp-credential \
  --key=cncamp.io.key \
  --cert=cncamp.io.crt
```

### 4. 配置 HTTPS Gateway

```bash
kubectl apply -f istio-specs.yaml -n securesvc
```

### 5. 测试 HTTPS 访问

```bash
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 使用 --resolve 指定域名解析
curl --resolve httpsserver.cncamp.io:443:$INGRESS_IP \
  https://httpsserver.cncamp.io/healthz -v -k
```

## 核心配置解析

### Gateway - HTTPS 配置

```yaml
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
      name: https-default
      number: 443
      protocol: HTTPS
    tls:
      mode: SIMPLE              # TLS 终止模式
      credentialName: cncamp-credential  # Secret 名称
```

### VirtualService

```yaml
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
  - match:
    - port: 443
    route:
    - destination:
        host: httpserver.securesvc.svc.cluster.local
        port:
          number: 80
```

## TLS 模式

| 模式 | 说明 |
|------|------|
| SIMPLE | TLS 终止（单向 TLS） |
| MUTUAL | 双向 TLS（mTLS） |
| PASSTHROUGH | TLS 透传 |

## 证书管理

### 使用 cert-manager 自动管理证书

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cncamp-cert
  namespace: istio-system
spec:
  secretName: cncamp-credential
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.cncamp.io"
```

## 清理

```bash
kubectl delete ns securesvc
kubectl delete secret cncamp-credential -n istio-system
rm cncamp.io.key cncamp.io.crt
```
