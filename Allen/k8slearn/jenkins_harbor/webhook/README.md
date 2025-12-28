# GitHub Webhook 配置指南 (内网穿透)

由于 Jenkins 部署在内网 (182.42.82.135)，GitHub 无法直接访问，需要使用 smee.io 做 Webhook 代理。

## 当前配置

- **smee.io URL**: `https://smee.io/EqVGH9FLtpCUtNiP`
- **Jenkins Webhook URL**: `http://localhost:30080/github-webhook/`
- **pysmee 状态**: 运行中

## 架构

```
GitHub Push → smee.io (公网代理) → pysmee (Master节点) → Jenkins (内网)
```

## 配置步骤

### 1. 获取 smee.io 通道

访问 https://smee.io/new，会自动生成一个通道 URL，如：
```
https://smee.io/xIgtwP3rRcQWPs5e
```

**保存这个 URL，后面要用！**

### 2. 在 Master 节点启动 pysmee

```bash
# SSH 到 Master 节点
ssh root@182.42.82.135

# 后台运行 pysmee (替换 YOUR_SMEE_URL)
nohup pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/ > /var/log/pysmee.log 2>&1 &

# 查看日志
tail -f /var/log/pysmee.log
```

### 3. 配置 GitHub Webhook

1. 进入 GitHub 仓库: https://github.com/tutengdihuang/service_test
2. Settings → Webhooks → Add webhook
3. 配置:
   - **Payload URL**: `https://smee.io/YOUR_CHANNEL` (你的 smee.io URL)
   - **Content type**: `application/json`
   - **Secret**: 留空 (或设置一个密钥)
   - **Events**: 选择 `Just the push event`
4. 点击 "Add webhook"

### 4. 在 Jenkins 安装 GitHub 插件

1. 访问 Jenkins: http://182.42.82.135:30080
2. Manage Jenkins → Plugins → Available plugins
3. 搜索并安装:
   - **GitHub Integration Plugin**
   - **GitHub plugin**
4. 重启 Jenkins

### 5. 配置 Jenkins Job

#### 方式 A: Pipeline 项目 (推荐)

1. 新建 Pipeline 项目
2. 在 "Build Triggers" 中勾选 **"GitHub hook trigger for GITScm polling"**
3. 在 Pipeline 配置中选择 "Pipeline script from SCM"
4. SCM: Git
5. Repository URL: `https://github.com/tutengdihuang/service_test.git`
6. Branch: `*/main`
7. Script Path: `Jenkinsfile` (或你的 Jenkinsfile 路径)

#### 方式 B: 在 Jenkinsfile 中配置

```groovy
pipeline {
    agent any
    
    triggers {
        githubPush()  // GitHub Webhook 触发
    }
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
    }
}
```

### 6. 测试 Webhook

1. 在 GitHub 仓库做一次 commit 并 push
2. 查看 smee.io 页面是否收到请求
3. 查看 pysmee 日志: `tail -f /var/log/pysmee.log`
4. 查看 Jenkins 是否触发构建

## 故障排查

### pysmee 没有收到消息

1. 检查 smee.io URL 是否正确
2. 检查 GitHub Webhook 配置是否正确
3. 在 GitHub Webhook 页面查看 "Recent Deliveries"

### Jenkins 没有触发构建

1. 确认 Jenkins 安装了 GitHub 插件
2. 确认 Job 配置了 "GitHub hook trigger for GITScm polling"
3. 查看 Jenkins 日志: `kubectl logs jenkins-0 -n devops`

### pysmee 进程退出

```bash
# 检查进程
ps aux | grep pysmee

# 重新启动
nohup pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/ > /var/log/pysmee.log 2>&1 &
```

## 使用 systemd 管理 pysmee (可选)

创建 systemd 服务文件:

```bash
cat > /etc/systemd/system/pysmee.service << 'EOF'
[Unit]
Description=pysmee webhook forwarder
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动
systemctl daemon-reload
systemctl enable pysmee
systemctl start pysmee

# 查看状态
systemctl status pysmee
```

## 替代方案

如果 smee.io 不稳定，可以考虑:

1. **ngrok**: 商业内网穿透工具
   ```bash
   ngrok http 30080
   ```

2. **frp**: 自建内网穿透服务

3. **pollSCM**: 定时轮询 (不需要 Webhook)
   ```groovy
   triggers {
       pollSCM('H/2 * * * *')  // 每 2 分钟检查一次
   }
   ```
