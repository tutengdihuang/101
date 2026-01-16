# 实验五：金丝雀发布

> 基于请求头的流量路由，实现金丝雀发布

## 实验目标

- 理解金丝雀发布的原理
- 掌握基于 Header 的流量路由
- 学会 DestinationRule 的子集定义

## 架构图

```
                    ┌─→ Header: user=jesse → v2 (金丝雀版本)
外部请求 → Gateway ─┤
                    └─→ 其他请求          → v1 (稳定版本)
```

## 实验步骤

### 1. 创建命名空间

```bash
kubectl create ns canary
kubectl label ns canary istio-injection=enabled
```

### 2. 部署 v1 版本

```bash
kubectl apply -f canary-v1.yaml -n canary
kubectl apply -f toolbox.yaml -n canary
```

### 3. 测试 v1 版本

```bash
# 进入 toolbox 容器
kubectl exec -it $(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}') -n canary -- curl canary/hello
```

### 4. 部署 v2 版本（金丝雀）

```bash
kubectl apply -f canary-v2.yaml -n canary
```

### 5. 配置流量路由规则

```bash
kubectl apply -f istio-specs.yaml -n canary
```

### 6. 测试金丝雀发布

```bash
# 普通请求 → v1
kubectl exec -it $(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}') -n canary -- curl canary/hello

# 带 Header 的请求 → v2
kubectl exec -it $(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}') -n canary -- curl canary/hello -H "user: jesse"
```

## 核心配置解析

### DestinationRule - 定义子集

```yaml
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
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
```

### VirtualService - 基于 Header 路由

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary
spec:
  hosts:
  - canary
  http:
  # 规则1：Header user=jesse → v2
  - match:
    - headers:
        user:
          exact: jesse
    route:
    - destination:
        host: canary
        subset: v2
  # 规则2：默认 → v1
  - route:
    - destination:
        host: canary
        subset: v1
```

## 金丝雀发布流程

```
1. 部署 v1 版本，100% 流量
2. 部署 v2 版本（金丝雀）
3. 配置路由：特定用户 → v2
4. 验证 v2 版本正常
5. 逐步扩大 v2 流量比例
6. 最终 100% 切换到 v2
```

## 按比例分流

```yaml
http:
- route:
  - destination:
      host: canary
      subset: v1
    weight: 90    # 90% 流量
  - destination:
      host: canary
      subset: v2
    weight: 10    # 10% 流量
```

## 清理

```bash
kubectl delete ns canary
```
