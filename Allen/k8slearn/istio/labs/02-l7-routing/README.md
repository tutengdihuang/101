# 实验二：七层路由

> 基于 URI 路径的流量路由和 URL 重写

## 实验目标

- 掌握基于 URI 的路由匹配
- 学会 URL 重写（rewrite）
- 理解多服务路由配置

## 架构图

```
                    ┌─→ /simple/hello → rewrite /hello → simple 服务
外部请求 → Gateway ─┤
                    └─→ /nginx        → rewrite /      → nginx 服务
```

## 实验步骤

### 1. 创建命名空间

```bash
kubectl create ns simple
kubectl label ns simple istio-injection=enabled
```

### 2. 部署两个服务

```bash
kubectl apply -f simple.yaml -n simple
kubectl apply -f nginx.yaml -n simple
```

### 3. 配置路由规则

```bash
kubectl apply -f istio-specs.yaml -n simple
```

### 4. 测试路由

```bash
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 访问 simple 服务（/simple/hello → /hello）
curl -H "Host: simple.cncamp.io" $INGRESS_IP/simple/hello

# 访问 nginx 服务（/nginx → /）
curl -H "Host: simple.cncamp.io" $INGRESS_IP/nginx
```

## 核心配置解析

```yaml
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
  # 规则1：/simple/hello → simple 服务的 /hello
  - match:
    - uri:
        exact: "/simple/hello"
    rewrite:
      uri: "/hello"              # URL 重写
    route:
    - destination:
        host: simple.simple.svc.cluster.local
        port:
          number: 80
  # 规则2：/nginx → nginx 服务的 /
  - match:
    - uri:
        prefix: "/nginx"
    rewrite:
      uri: "/"
    route:
    - destination:
        host: nginx.simple.svc.cluster.local
        port:
          number: 80
```

## URI 匹配方式

| 方式 | 说明 | 示例 |
|------|------|------|
| exact | 精确匹配 | `/api/v1` 只匹配 `/api/v1` |
| prefix | 前缀匹配 | `/api` 匹配 `/api`、`/api/v1`、`/api/v2` |
| regex | 正则匹配 | `/api/v[0-9]+` 匹配 `/api/v1`、`/api/v2` |

## 清理

```bash
kubectl delete ns simple
```
