# 实验八：认证（PeerAuthentication）

> mTLS 双向认证：服务间加密通信

## 实验目标

- 理解 mTLS 的工作原理
- 掌握 PeerAuthentication 的三种模式
- 学会从 PERMISSIVE 迁移到 STRICT

## 架构图

```
┌─────────────────────────────────────────────────────────┐
│                     Istiod (CA)                         │
│                   证书颁发机构                           │
└─────────────────────────────────────────────────────────┘
                        ↓ 证书下发
┌──────────────┐  mTLS  ┌──────────────┐
│   sleep      │ ←────→ │   httpbin    │
│ (有 Sidecar) │ 加密通信│ (有 Sidecar) │
└──────────────┘        └──────────────┘

┌──────────────┐  HTTP  ┌──────────────┐
│   sleep      │ ←────→ │   httpbin    │
│ (无 Sidecar) │ 明文通信│ (有 Sidecar) │
└──────────────┘        └──────────────┘
```

## 实验步骤

### 1. 准备环境

```bash
# 创建三个命名空间
kubectl create ns foo
kubectl create ns bar
kubectl create ns legacy

# foo 和 bar 启用 Sidecar 注入
kubectl label ns foo istio-injection=enabled
kubectl label ns bar istio-injection=enabled
# legacy 不启用（模拟遗留系统）
```

### 2. 部署测试应用

```bash
# foo 和 bar 命名空间（有 Sidecar）
kubectl apply -f <(istioctl kube-inject -f httpbin.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f sleep.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f httpbin.yaml) -n bar
kubectl apply -f <(istioctl kube-inject -f sleep.yaml) -n bar

# legacy 命名空间（无 Sidecar）
kubectl apply -f httpbin.yaml -n legacy
kubectl apply -f sleep.yaml -n legacy
```

### 3. 测试连通性（默认 PERMISSIVE 模式）

```bash
# 测试所有组合
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done
```

预期结果：全部返回 200（PERMISSIVE 模式接受 mTLS 和明文）

### 4. 验证 mTLS 通信

```bash
# 查看请求头，确认 Sidecar 间使用 mTLS
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl -s http://httpbin.foo:8000/headers
```

### 5. 启用全局 STRICT 模式

```bash
kubectl apply -f - <<EOF
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

### 6. 再次测试连通性

```bash
# 测试所有组合
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done
```

预期结果：
- foo → foo/bar: 200（mTLS）
- bar → foo/bar: 200（mTLS）
- legacy → foo/bar: 失败（无证书）
- 所有 → legacy: 200（legacy 无 Sidecar，不强制 mTLS）

### 7. 为特定服务禁用 mTLS（可选）

```bash
kubectl apply -f - <<EOF
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
```

## PeerAuthentication 模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| PERMISSIVE | 接受 mTLS 和明文 | 迁移过渡期 |
| STRICT | 只接受 mTLS | 生产环境 |
| DISABLE | 禁用 mTLS | 特殊场景 |

## 配置优先级

```
服务级别 > 命名空间级别 > 全局级别
```

## 清理

```bash
kubectl delete ns foo bar legacy
kubectl delete peerauthentication default -n istio-system
```
