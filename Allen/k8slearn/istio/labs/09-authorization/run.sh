#!/bin/bash
# AuthorizationPolicy 实验脚本

set -e

echo "=== 实验九：AuthorizationPolicy ==="

# 检查前置条件
if ! kubectl get ns foo &>/dev/null; then
    echo "错误：请先完成实验八（PeerAuthentication）"
    exit 1
fi

# 1. 创建默认拒绝策略
echo "1. 创建默认拒绝策略..."
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-nothing
  namespace: foo
spec:
  {}
EOF

sleep 3

# 2. 测试访问（应该全部失败）
echo ""
echo "=== 测试访问（deny all）==="
echo "从 bar 访问 foo:"
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n" || echo "failed"

echo "从 foo 访问 foo:"
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n" || echo "failed"

# 3. 允许 GET 方法
echo ""
echo "2. 允许 GET 方法访问..."
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

sleep 3

# 4. 测试访问（GET 应该成功）
echo ""
echo "=== 测试访问（允许 GET）==="
echo "从 bar 访问 foo:"
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

echo "从 foo 访问 foo:"
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

# 5. 只允许 bar 访问
echo ""
echo "3. 只允许 bar/sleep 访问..."
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

sleep 3

# 6. 测试访问（只有 bar 能访问）
echo ""
echo "=== 测试访问（只允许 bar）==="
echo "从 bar 访问 foo (应该成功):"
kubectl exec "$(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name})" \
  -c sleep -n bar -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

echo "从 foo 访问 foo (应该失败):"
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" \
  -c sleep -n foo -- curl http://httpbin.foo:8000/headers -s -o /dev/null -w "%{http_code}\n"

echo ""
echo "=== 实验完成 ==="
echo "清理命令:"
echo "  kubectl delete authorizationpolicy --all -n foo"
echo "  kubectl delete ns foo bar legacy"
