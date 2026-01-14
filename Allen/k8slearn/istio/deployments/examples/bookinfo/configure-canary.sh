#!/bin/bash

set -e

NAMESPACE="bookinfo"

echo "========================================="
echo "BookInfo 灰度发布配置脚本 v1.0"
echo "========================================="
echo ""

if [ "$1" == "uninstall" ]; then
    echo "卸载灰度发布配置..."
    kubectl delete virtualservice reviews -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete destinationrule reviews -n ${NAMESPACE} --ignore-not-found=true
    echo "✓ 灰度发布配置已卸载"
    exit 0
fi

echo "步骤 1/3: 创建 reviews 服务的 VirtualService..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: ${NAMESPACE}
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF
echo "✓ VirtualService 已创建（100% 流量到 v1）"

echo ""
echo "步骤 2/3: 创建 reviews 服务的 DestinationRule..."
kubectl apply -f ../../destinationrules/bookinfo-dr.yaml -n ${NAMESPACE}
echo "✓ DestinationRule 已创建"

echo ""
echo "步骤 3/3: 配置灰度发布..."

echo ""
echo "场景 1: 将 50% 流量导向 v2（灰度发布）"
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: ${NAMESPACE}
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
echo "✓ 50% 流量已导向 v2"

echo ""
echo "========================================="
echo "灰度发布配置完成！"
echo "========================================="
echo ""
echo "当前流量分配:"
echo "  - v1: 50%"
echo "  - v2: 50%"
echo ""
echo "测试灰度发布:"
echo "  for i in \$(seq 1 20); do curl -s http://<INGRESS_HOST>/productpage | grep -o 'reviews-v[1-3]'; done"
echo ""
echo "调整流量分配:"
echo "  ./adjust-traffic.sh <v1-weight> <v2-weight>"
echo ""
echo "示例: 将 90% 流量导向 v1，10% 流量导向 v2"
echo "  ./adjust-traffic.sh 90 10"
