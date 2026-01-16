#!/bin/bash
# PeerAuthentication 实验脚本

set -e

echo "=== 实验八：PeerAuthentication (mTLS) ==="

# 1. 创建命名空间
echo "1. 创建命名空间..."
kubectl create ns foo 2>/dev/null || true
kubectl create ns bar 2>/dev/null || true
kubectl create ns legacy 2>/dev/null || true

kubectl label ns foo istio-injection=enabled --overwrite
kubectl label ns bar istio-injection=enabled --overwrite
# legacy 不启用 Sidecar 注入

# 2. 部署测试应用
echo "2. 部署测试应用..."
# 使用 Istio 官方示例
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/sleep/sleep.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml) -n bar
kubectl apply -f <(istioctl kube-inject -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/sleep/sleep.yaml) -n bar
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml -n legacy
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/sleep/sleep.yaml -n legacy

# 3. 等待 Pod 就绪
echo "3. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=httpbin -n foo --timeout=120s
kubectl wait --for=condition=ready pod -l app=sleep -n foo --timeout=120s
kubectl wait --for=condition=ready pod -l app=httpbin -n bar --timeout=120s
kubectl wait --for=condition=ready pod -l app=sleep -n bar --timeout=120s
kubectl wait --for=condition=ready pod -l app=httpbin -n legacy --timeout=120s
kubectl wait --for=condition=ready pod -l app=sleep -n legacy --timeout=120s

# 4. 测试连通性（PERMISSIVE 模式）
echo ""
echo "=== 测试连通性（默认 PERMISSIVE 模式）==="
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"
  done
done

# 5. 启用 STRICT 模式
echo ""
echo "=== 启用全局 STRICT 模式 ==="
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

sleep 5

# 6. 再次测试连通性
echo ""
echo "=== 测试连通性（STRICT 模式）==="
for from in "foo" "bar" "legacy"; do
  for to in "foo" "bar" "legacy"; do
    result=$(kubectl exec "$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})" \
      -c sleep -n ${from} -- curl -s "http://httpbin.${to}:8000/ip" \
      -o /dev/null -w "%{http_code}" 2>/dev/null || echo "failed")
    echo "sleep.${from} to httpbin.${to}: ${result}"
  done
done

echo ""
echo "=== 实验完成 ==="
echo "预期结果："
echo "  - foo/bar → foo/bar: 200 (mTLS)"
echo "  - legacy → foo/bar: 失败 (无证书)"
echo "  - 所有 → legacy: 200 (无 Sidecar)"
echo ""
echo "清理命令:"
echo "  kubectl delete ns foo bar legacy"
echo "  kubectl delete peerauthentication default -n istio-system"
