#!/bin/bash

set -e

NAMESPACE="bookinfo"
GATEWAY_URL="http://10.0.3.231:31868"
REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"

echo "=========================================="
echo "Istio 流量管理测试脚本"
echo "=========================================="

echo ""
echo "1. 测试场景：将所有流量路由到 v1"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-v1.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-v1.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 20 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..20}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "2. 测试场景：将所有流量路由到 v2"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-v2.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-v2.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 20 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..20}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "3. 测试场景：将所有流量路由到 v3"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-v3.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v3
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-v3.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 20 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..20}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "4. 测试场景：50% 流量到 v1，50% 流量到 v2"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-split.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v2
      weight: 50
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-split.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 40 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..40}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "5. 测试场景：90% 流量到 v1，10% 流量到 v3（金丝雀发布）"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-canary.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v3
      weight: 10
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-canary.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 50 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..50}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "6. 恢复默认流量分配（随机分配到所有版本）"
echo "------------------------------------------"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/reviews-vs-default.yaml" << 'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
EOF

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/reviews-vs-default.yaml -n ${NAMESPACE}"

echo "等待配置生效..."
sleep 3

echo "发送 30 个请求..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
for i in {1..30}; do
    curl -s "http://10.0.3.231:31868/productpage" | grep -o 'reviews-v[0-9]'
done | sort | uniq -c
ENDSSH

echo ""
echo "=========================================="
echo "流量管理测试完成"
echo "=========================================="

echo ""
echo "7. 显示当前 Istio 配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get gateway,virtualservice,destinationrule -n ${NAMESPACE}"

echo ""
echo "8. 显示 reviews VirtualService 配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get virtualservice reviews -n ${NAMESPACE} -o yaml | grep -A 20 'spec:'"
