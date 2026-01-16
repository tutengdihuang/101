# 实验九：授权（AuthorizationPolicy）

> 细粒度访问控制：谁能访问谁

## 实验目标

- 理解 AuthorizationPolicy 的工作原理
- 掌握 ALLOW 和 DENY 规则
- 学会基于服务身份的访问控制

## 架构图

```
┌──────────────┐     ALLOW      ┌──────────────┐
│  bar/sleep   │ ─────────────→ │  foo/httpbin │
│  (允许访问)   │                │              │
└──────────────┘                └──────────────┘

┌──────────────┐     DENY       ┌──────────────┐
│  foo/sleep   │ ──────X──────→ │  foo/httpbin │
│  (拒绝访问)   │                │              │
└──────────────┘                └──────────────┘
```

## 实验步骤

### 前置条件

先完成实验八（PeerAuthentication），确保 foo 和 bar 命名空间存在。

### 1. 创建默认拒绝策略

```bash
# 在 foo 命名空间创建 "deny all" 策略
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: foo
spec:
  {}
EOF
```

### 2. 测试访问（应该全部失败）

```bash
# 从 bar 访问 foo
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

# 从 foo 访问 foo
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"
```

预期结果：都返回 403（RBAC: access denied）

### 3. 允许 GET 方法访问

```bash
kubectl apply -f - <<EOF
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

### 4. 测试访问（GET 应该成功）

```bash
# 从 bar 访问 foo（GET）
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

# 从 foo 访问 foo（GET）
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"
```

预期结果：都返回 200

### 5. 只允许特定服务访问

```bash
kubectl apply -f - <<EOF
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
        principals: ["cluster.local/ns/bar/sa/sleep"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

### 6. 测试访问（只有 bar 能访问）

```bash
# 从 bar 访问 foo（应该成功）
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

# 从 foo 访问 foo（应该失败）
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"
```

预期结果：bar → foo 返回 200，foo → foo 返回 403

## AuthorizationPolicy 规则

### 动作类型

| 动作 | 说明 |
|------|------|
| ALLOW | 允许匹配的请求 |
| DENY | 拒绝匹配的请求 |
| CUSTOM | 自定义授权 |

### 规则字段

```yaml
rules:
- from:                    # 来源
  - source:
      principals: [...]    # 服务身份
      namespaces: [...]    # 命名空间
      ipBlocks: [...]      # IP 地址
  to:                      # 目标
  - operation:
      methods: [...]       # HTTP 方法
      paths: [...]         # URL 路径
      hosts: [...]         # 主机名
  when:                    # 条件
  - key: ...
    values: [...]
```

### 服务身份格式

```
cluster.local/ns/<namespace>/sa/<service-account>
```

## 清理

```bash
kubectl delete authorizationpolicy --all -n foo
kubectl delete ns foo bar legacy
```
