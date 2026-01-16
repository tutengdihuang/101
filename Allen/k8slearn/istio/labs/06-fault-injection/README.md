# 实验六：故障注入

> 测试系统的健壮性：超时、重试、故障注入

## 实验目标

- 掌握超时（timeout）配置
- 掌握重试（retry）配置
- 学会故障注入（fault injection）

## 实验场景

```
场景1：超时测试
  - 如果上游服务响应超过 1s，返回超时错误

场景2：重试 + 故障注入
  - 80% 请求返回 500 错误
  - 自动重试 3 次
```

## 实验步骤

### 前置条件

先完成实验五（金丝雀发布），确保 canary 命名空间存在。

### 场景1：超时测试

```bash
# 应用超时配置
kubectl apply -f timeout.yaml -n canary

# 测试：如果 v2 响应超过 1s，会返回超时错误
kubectl exec -it $(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}') -n canary -- curl canary/hello -H "user: jesse" -v
```

### 场景2：重试 + 故障注入

```bash
# 应用重试和故障注入配置
kubectl apply -f retry.yaml -n canary

# 测试：v1 有 80% 概率返回 500，但会自动重试
kubectl exec -it $(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}') -n canary -- curl canary/hello -v
```

## 核心配置解析

### 超时配置

```yaml
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
          exact: jesse
    route:
    - destination:
        host: canary
        subset: v2
    timeout: 1s    # 超时时间 1 秒
```

### 重试配置

```yaml
http:
- route:
  - destination:
      host: canary
      subset: v2
  retries:
    attempts: 3        # 重试 3 次
    perTryTimeout: 2s  # 每次重试超时 2 秒
```

### 故障注入

```yaml
http:
- route:
  - destination:
      host: canary
      subset: v1
  fault:
    abort:
      httpStatus: 500      # 返回 500 错误
      percentage:
        value: 80          # 80% 的请求
```

## 故障注入类型

| 类型 | 说明 | 用途 |
|------|------|------|
| delay | 注入延迟 | 测试超时处理 |
| abort | 注入错误 | 测试错误处理 |

### 延迟注入示例

```yaml
fault:
  delay:
    fixedDelay: 5s       # 延迟 5 秒
    percentage:
      value: 100         # 100% 的请求
```

## 清理

```bash
kubectl delete ns canary
```
