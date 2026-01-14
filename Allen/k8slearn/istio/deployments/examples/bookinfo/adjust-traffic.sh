#!/bin/bash

set -e

NAMESPACE="bookinfo"

if [ $# -ne 2 ]; then
    echo "用法: ./adjust-traffic.sh <v1-weight> <v2-weight>"
    echo "示例: ./adjust-traffic.sh 90 10"
    echo "说明: v1-weight + v2-weight 应该等于 100"
    exit 1
fi

V1_WEIGHT=$1
V2_WEIGHT=$2

if [ $((V1_WEIGHT + V2_WEIGHT)) -ne 100 ]; then
    echo "错误: v1-weight + v2-weight 必须等于 100"
    exit 1
fi

echo "========================================="
echo "调整流量权重"
echo "========================================="
echo ""
echo "新的流量分配:"
echo "  - v1: ${V1_WEIGHT}%"
echo "  - v2: ${V2_WEIGHT}%"
echo ""

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
      weight: ${V1_WEIGHT}
    - destination:
        host: reviews
        subset: v2
      weight: ${V2_WEIGHT}
EOF

echo "✓ 流量权重已调整"
echo ""
echo "验证流量分配:"
echo "  kubectl get virtualservice reviews -n ${NAMESPACE} -o yaml | grep -A 10 weight"
