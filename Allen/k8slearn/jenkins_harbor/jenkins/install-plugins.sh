#!/bin/bash
# Jenkins 插件安装脚本
# 在 Jenkins Pod 中执行

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="${1:-admin123}"

# 等待 Jenkins 启动
echo "等待 Jenkins 启动..."
until curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL/login" | grep -q "200"; do
    sleep 5
    echo "Jenkins 还未就绪，等待中..."
done
echo "Jenkins 已启动"

# 获取 crumb (CSRF token)
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumb')
CRUMB_HEADER=$(curl -s -u "$JENKINS_USER:$JENKINS_PASS" "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumbRequestField')

if [ -z "$CRUMB" ] || [ "$CRUMB" == "null" ]; then
    echo "无法获取 CSRF token，可能需要先完成初始化向导"
    exit 1
fi

echo "CSRF Token: $CRUMB"

# 安装插件列表
PLUGINS=(
    "workflow-aggregator"
    "git"
    "github"
    "github-branch-source"
    "docker-workflow"
    "kubernetes"
    "kubernetes-cli"
    "credentials-binding"
    "pipeline-stage-view"
    "blueocean"
    "configuration-as-code"
    "job-dsl"
)

echo "开始安装插件..."
for plugin in "${PLUGINS[@]}"; do
    echo "安装插件: $plugin"
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASS" \
        -H "$CRUMB_HEADER: $CRUMB" \
        "$JENKINS_URL/pluginManager/installNecessaryPlugins" \
        -d "<install plugin='$plugin@latest' />"
done

echo ""
echo "插件安装请求已发送"
echo "请访问 $JENKINS_URL/pluginManager/installed 查看安装状态"
echo "安装完成后需要重启 Jenkins"
