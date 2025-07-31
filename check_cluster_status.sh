#!/bin/bash

# 设置密码
PASSWORD="1Qaz2Wsx"

echo "=== 检查 Master 节点状态 ==="
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@182.42.82.135 << 'EOF'
echo "主机名: $(hostname)"
echo "IP地址:"
ip addr show | grep -E "inet.*scope global"
echo "Docker状态:"
systemctl status docker --no-pager -l
echo "Kubernetes组件状态:"
systemctl status kubelet --no-pager -l 2>/dev/null || echo "kubelet未安装"
echo "已安装的包:"
dpkg -l | grep -E "(docker|kube)" || echo "未找到相关包"
EOF

echo -e "\n=== 检查 Worker1 节点状态 ==="
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@182.42.80.121 << 'EOF'
echo "主机名: $(hostname)"
echo "IP地址:"
ip addr show | grep -E "inet.*scope global"
echo "Docker状态:"
systemctl status docker --no-pager -l
echo "Kubernetes组件状态:"
systemctl status kubelet --no-pager -l 2>/dev/null || echo "kubelet未安装"
EOF

echo -e "\n=== 检查 Worker2 节点状态 ==="
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@182.42.95.71 << 'EOF'
echo "主机名: $(hostname)"
echo "IP地址:"
ip addr show | grep -E "inet.*scope global"
echo "Docker状态:"
systemctl status docker --no-pager -l
echo "Kubernetes组件状态:"
systemctl status kubelet --no-pager -l 2>/dev/null || echo "kubelet未安装"
EOF 