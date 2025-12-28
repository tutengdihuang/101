#!/bin/bash
# smee.io webhook 代理启动脚本
# 用于将 GitHub Webhook 转发到内网 Jenkins

# 配置
SMEE_URL="${SMEE_URL:-https://smee.io/YOUR_CHANNEL}"  # 替换为你的 smee.io URL
JENKINS_URL="http://localhost:30080/github-webhook/"

# 检查 SMEE_URL 是否已配置
if [[ "$SMEE_URL" == *"YOUR_CHANNEL"* ]]; then
    echo "错误: 请先配置 SMEE_URL"
    echo "1. 访问 https://smee.io/new 获取通道 URL"
    echo "2. 设置环境变量: export SMEE_URL=https://smee.io/xxxxx"
    echo "3. 或直接修改本脚本中的 SMEE_URL"
    exit 1
fi

echo "启动 smee.io webhook 代理..."
echo "SMEE URL: $SMEE_URL"
echo "Jenkins URL: $JENKINS_URL"
echo ""
echo "按 Ctrl+C 停止"
echo ""

# 启动 pysmee
pysmee forward "$SMEE_URL" "$JENKINS_URL"
