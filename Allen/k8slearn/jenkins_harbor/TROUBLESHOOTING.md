# Jenkins + Harbor CI/CD 问题排查总结

## 问题 1：Jenkins Job 配置 "No flow definition"

**错误信息**：
```
ERROR: No flow definition, cannot run
Finished: FAILURE
```

**原因**：
- Jenkins Job 的 config.xml 文件格式错误或未正确加载
- XML 中存在转义字符问题（如 `\</projectUrl\>` 应为 `</projectUrl>`）

**解决方案**：
1. 删除错误的 Job 配置
2. 重新创建正确格式的 config.xml
3. 重启 Jenkins Pod 加载新配置

```bash
# 删除旧配置
kubectl exec jenkins-0 -n devops -- rm -rf /var/jenkins_home/jobs/service-test

# 复制正确的配置文件
kubectl cp job-config.xml devops/jenkins-0:/var/jenkins_home/jobs/service-test/config.xml

# 重启 Jenkins
kubectl delete pod jenkins-0 -n devops
```

---

## 问题 2：Jenkins 无法连接 GitHub

**错误信息**：
```
ERROR: Error cloning remote repo 'origin'
error: RPC failed; curl 28 Failed to connect to github.com port 443 after 130731 ms
```

**原因**：
- 国内服务器访问 GitHub 网络不稳定
- 网络超时

**解决方案**：
1. 等待网络恢复后重试
2. 考虑使用 GitHub 代理或镜像
3. 或改用 GitLab 等国内可访问的代码仓库

---

## 问题 3：Docker 无法拉取基础镜像

**错误信息**：
```
Step 1/17 : FROM golang:1.24-alpine AS builder
Get "https://registry-1.docker.io/v2/": context deadline exceeded
```

**原因**：
- 国内服务器无法直接访问 Docker Hub
- 网络超时

**解决方案**：
配置 Docker 使用国内镜像源：

```bash
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["<MASTER_IP>:30002"],
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://registry.docker-cn.com"
  ]
}
EOF
systemctl restart docker
```

---

## 问题 4：Jenkins API 认证失败

**错误信息**：
```
HTTP ERROR 401 Unauthorized
```

**原因**：
- Jenkins API 需要用户名 + API Token 认证
- 还需要 CRUMB（CSRF 保护）

**解决方案**：
1. 在 Jenkins 界面生成 API Token：
   - 用户名 → Security → API Token → Add new Token
2. 使用 CRUMB 调用 API：

```bash
# 获取 CRUMB
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' \
  --user 'admin:API_TOKEN' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)

# 调用 API
curl -X POST 'http://localhost:30080/job/service-test/build' \
  --user 'admin:API_TOKEN' \
  -H "Jenkins-Crumb: $CRUMB"
```

---

## 问题 5：smee-client 安装依赖冲突

**错误信息**：
```
npm ERR! conflicting peer dependency
```

**原因**：
- Node.js 版本与 npm 包依赖冲突

**解决方案**：
使用 pysmee（Python 版本）替代：

```bash
pip install pysmee
pysmee forward https://smee.io/YOUR_CHANNEL http://localhost:30080/github-webhook/
```

---

## 问题 6：Harbor 凭证未配置

**错误信息**：
```
CredentialNotFoundException: harbor-credentials
```

**原因**：
- Jenkins 中未配置 Harbor 登录凭证

**解决方案**：
在 Jenkins 中添加凭证：
1. Manage Jenkins → Credentials → System → Global credentials
2. Add Credentials:
   - Kind: Username with password
   - Username: `admin`
   - Password: `Harbor12345`
   - ID: `harbor-credentials`

---

## 配置检查清单

| 检查项 | 状态 | 说明 |
|--------|------|------|
| Jenkins Pod 运行 | ✅ | `kubectl get pod jenkins-0 -n devops` |
| Harbor 运行 | ✅ | `curl http://<MASTER_IP>:30002/api/v2.0/health` |
| smee-client 运行 | ✅ | `ps aux \| grep smee` |
| Docker 镜像源配置 | ✅ | `/etc/docker/daemon.json` |
| Harbor 凭证配置 | ✅ | Jenkins Credentials |
| GitHub Webhook 配置 | ✅ | GitHub Settings → Webhooks |
| Jenkinsfile 存在 | ✅ | 项目根目录 |

---

## 常用调试命令

```bash
# 查看 Jenkins 日志
kubectl logs jenkins-0 -n devops --tail=50

# 查看构建日志
kubectl exec jenkins-0 -n devops -- cat /var/jenkins_home/jobs/service-test/builds/LATEST/log

# 检查 Docker 是否可用
kubectl exec jenkins-0 -n devops -- docker version

# 检查 Harbor 连接
kubectl exec jenkins-0 -n devops -- docker login <MASTER_IP>:30002 -u admin -p Harbor12345

# 检查 GitHub 网络
kubectl exec jenkins-0 -n devops -- curl -I https://github.com

# 手动触发构建
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' --user 'admin:TOKEN' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)
curl -X POST 'http://localhost:30080/job/service-test/build' --user 'admin:TOKEN' -H "Jenkins-Crumb: $CRUMB"
```


---

## 问题 7：GitHub TLS 连接中断

**错误信息**：
```
fatal: unable to access 'https://github.com/tutengdihuang/service_test.git/': 
GnuTLS recv error (-110): The TLS connection was non-properly terminated
```

**原因**：
- 从中国访问 GitHub 网络不稳定
- TLS 握手过程中连接被中断

**解决方案**：
1. 等待网络恢复后重试构建
2. 多次重试，网络通常会间歇性恢复
3. 如果持续失败，考虑使用 Git 代理

```bash
# 手动触发重新构建
CRUMB=$(curl -s 'http://localhost:30080/crumbIssuer/api/json' --user 'admin:API_TOKEN' | grep -o '"crumb":"[^"]*' | cut -d'"' -f4)
curl -X POST 'http://localhost:30080/job/service-test/build' --user 'admin:API_TOKEN' -H "Jenkins-Crumb: $CRUMB"
```

---

## 问题 8：Jenkins Pod 中没有 kubectl

**错误信息**：
```
/var/jenkins_home/workspace/service-test@tmp/durable-xxx/script.sh.copy: 2: kubectl: not found
```

**原因**：
- Jenkins 官方镜像不包含 kubectl
- Deploy 阶段需要 kubectl 来更新 K8s deployment

**解决方案**：
在 Jenkins Pod 中手动安装 kubectl：

```bash
kubectl exec jenkins-0 -n devops -- bash -c '
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl" && \
chmod +x kubectl && \
mv kubectl /usr/local/bin/
'
```

**永久解决**：
可以构建自定义 Jenkins 镜像，预装 kubectl。

---

## 问题 9：kubectl 无法解析 K8s API Server 主机名

**错误信息**：
```
dial tcp: lookup k8s-master-internal on 10.96.0.10:53: no such host
```

**原因**：
- kubeconfig 中的 server 地址使用了内部主机名 `k8s-master-internal`
- Jenkins Pod 内部 DNS 无法解析该主机名

**解决方案**：
1. 复制 kubeconfig 到 Jenkins Pod
2. 将 server 地址从主机名改为 IP 地址

```bash
# 创建目录
kubectl exec jenkins-0 -n devops -- mkdir -p /var/jenkins_home/.kube

# 复制 kubeconfig
kubectl cp /root/.kube/config devops/jenkins-0:/var/jenkins_home/.kube/config

# 修改 server 地址为 IP
kubectl exec jenkins-0 -n devops -- sed -i 's|https://k8s-master-internal:6443|https://<MASTER_IP>:6443|g' /var/jenkins_home/.kube/config

# 验证
kubectl exec jenkins-0 -n devops -- kubectl --kubeconfig=/var/jenkins_home/.kube/config get nodes
```

---

## 问题 10：Jenkinsfile 缺少 KUBECONFIG 环境变量

**错误信息**：
kubectl 命令执行时找不到配置文件，默认路径不存在。

**原因**：
- kubectl 默认查找 `~/.kube/config`
- Jenkins 工作目录不是用户 home 目录

**解决方案**：
在 Jenkinsfile 的 environment 中添加 KUBECONFIG：

```groovy
environment {
    // ... 其他配置
    KUBECONFIG = '/var/jenkins_home/.kube/config'
}
```

---

## 问题 11：kubectl set image 容器名不匹配

**错误信息**：
虽然命令执行成功，但镜像未更新，因为容器名不匹配。

**原因**：
- Deployment 中的容器名与 Jenkinsfile 中指定的不一致
- 例如：web-service deployment 的容器名是 `web-service` 而不是 `web`

**解决方案**：
检查 deployment 的容器名：
```bash
kubectl get deployments -n service-test -o wide
```

更新 Jenkinsfile，为每个服务指定正确的容器名：

```groovy
def services = [
    [name: 'user', container: 'user'],
    [name: 'product', container: 'product'],
    [name: 'trade', container: 'trade'],
    [name: 'web', container: 'web-service']  // 注意这里
]

services.each { svc ->
    sh """
        kubectl set image deployment/${svc.name}-service \
            ${svc.container}=${imageName}:${imageTag} \
            -n ${K8S_NAMESPACE}
    """
}
```

---

## 当前状态 (2025-12-27)

| 组件 | 状态 | 说明 |
|------|------|------|
| Jenkins | ✅ 运行中 | kubectl 已安装，kubeconfig 已配置 |
| Harbor | ✅ 运行中 | 4 个服务镜像已推送 (tag:5) |
| 镜像构建 | ✅ 成功 | user/product/trade/web 全部构建成功 |
| 镜像推送 | ✅ 成功 | 已推送到 Harbor |
| K8s 部署 | ✅ 已更新 | 手动执行 kubectl set image 更新 |
| Jenkinsfile | ⏳ 待推送 | 已添加 KUBECONFIG 和容器名映射 |

**下一步**：
将更新后的 Jenkinsfile 推送到 GitHub，完成完整的 CI/CD 流程验证。


---

## 问题 12：smee-client 进程意外停止

**现象**：
推送代码后 webhook 没有触发 Jenkins 构建。

**原因**：
smee-client (pysmee) 进程已停止运行。

**解决方案**：
重新启动 smee-client：

```bash
# 检查进程是否运行
ps aux | grep smee | grep -v grep

# 重新启动
nohup pysmee forward https://smee.io/EqVGH9FLtpCUtNiP http://localhost:30080/github-webhook/ > /var/log/smee.log 2>&1 &
```

**建议**：
使用 systemd 服务管理 smee-client，确保开机自启和自动重启。

---

## 问题 13：pysmee 处理 webhook 消息出错

**错误信息**：
```
ERROR: Exception Unterminated string starting at: line 1 column 4039 (char 4038) processing message
```

**原因**：
pysmee 在解析 GitHub webhook 的 JSON 消息时出错，可能是消息过大或格式问题。

**解决方案**：
1. 尝试使用 Node.js 版本的 smee-client（需要 Node.js 20+）
2. 或者忽略此错误，pysmee 仍然可以转发大部分 webhook

---

## 问题 14：Node.js smee-client 不兼容

**错误信息**：
```
ReferenceError: File is not defined
    at Object.<anonymous> (/usr/local/lib/node_modules/smee-client/node_modules/undici/lib/web/webidl/index.js:531:48)
```

**原因**：
Node.js 18.x 版本太旧，smee-client 最新版需要 Node.js 20+。

**解决方案**：
1. 升级 Node.js 到 20+ 版本
2. 或继续使用 pysmee

```bash
# 升级 Node.js (可选)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
```

---

## 问题 15：GitHub 网络连接超时（间歇性）

**错误信息**：
```
curl 28 Failed to connect to github.com port 443 after 130969 ms: Could not connect to server
```

**原因**：
从中国访问 GitHub 网络不稳定，连接超时。

**判断依据**：
- `curl 28` 是 curl 超时错误码
- `130969 ms` 表示等待了约 131 秒
- 同样的配置在其他构建中成功过

**解决方案**：
1. 重试构建，等待网络恢复
2. 配置 Git 代理
3. 使用 GitHub 镜像（如 gitee 同步）

---

## 最终状态 (2025-12-27)

### CI/CD 全流程验证结果

| 环节 | 状态 | 说明 |
|------|------|------|
| GitHub Webhook | ✅ | 推送触发 smee.io 转发 |
| smee-client | ✅ | 转发 webhook 到 Jenkins |
| Jenkins 触发 | ✅ | 构建 #7 被自动触发 |
| 代码拉取 | ⚠️ | 依赖 GitHub 网络（间歇性） |
| Docker 构建 | ✅ | 4 个服务镜像构建成功 |
| Harbor 推送 | ✅ | 镜像推送到私有仓库 |
| K8s 部署 | ✅ | kubectl set image 更新成功 |
| Pod 运行 | ✅ | 所有服务正常运行 |

### 成功的构建记录

- **构建 #5**: 首次完整构建成功（镜像构建+推送）
- **构建 #6**: 完整流程成功（构建+推送+部署+验证）
- **构建 #7**: Webhook 触发成功，但 GitHub 网络超时

### 当前运行的服务

```bash
kubectl get deployments -n service-test -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'
```

输出：
```
product-service: <MASTER_IP>:30002/service-test/product-service:6
trade-service: <MASTER_IP>:30002/service-test/trade-service:6
user-service: <MASTER_IP>:30002/service-test/user-service:6
web-service: <MASTER_IP>:30002/service-test/web-service:6
```

### 结论

**Jenkins + Harbor CI/CD 流水线已完全打通**，全流程验证成功。唯一的不稳定因素是从中国访问 GitHub 的网络问题，这是外部因素，不影响流水线本身的正确性。
