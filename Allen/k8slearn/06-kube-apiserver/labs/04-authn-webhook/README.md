# Lab 04 - Token Webhook 认证（kube-apiserver authentication-token-webhook）

## 目标

- 在 kube-apiserver 启用 `--authentication-token-webhook-config-file`
- 运行一个符合 `TokenReview` 规范的认证服务（本仓库示例：`module6/authn-webhook`）
- 通过 `kubectl --user <name>` 携带 token 发起请求，观察认证链路生效

## 对应来源

- 本仓库：`module6/authn-webhook/readme.MD`
- 本仓库：`module6/authn-webhook/main.go`
- 本仓库：`module6/authn-webhook/webhook-config.json`
- 本仓库：`module6/authn-webhook/specs/kube-apiserver.yaml`
- 训练营：模块六（API Server）-> 认证插件（Webhook 令牌认证）

## 前置条件

- kubeadm 安装的集群，apiserver 静态 Pod：`/etc/kubernetes/manifests/kube-apiserver.yaml`
- 控制平面节点能运行一个 HTTP 服务（本文示例服务端口 `3000`）
- 你能在控制平面节点上编译/运行 Go 程序（或直接使用编译产物）

## 实验步骤

### 1. 在控制平面节点启动 authn-webhook 服务

在项目根目录：

```sh
cd /Volumes/mac_data/code/go_code/101/module6/authn-webhook
make build
./bin/amd64/authn-webhook
```

默认会提供一个 `/authenticate` 端点，接收 apiserver 的 `TokenReview` 请求并返回认证结果。

### 2. 准备 apiserver webhook 配置

在控制平面节点上：

```sh
sudo mkdir -p /etc/config
sudo cp /Volumes/mac_data/code/go_code/101/module6/authn-webhook/webhook-config.json /etc/config/webhook-config.json
```

说明：该文件告诉 apiserver 如何访问认证服务（示例：`http://192.168.34.2:3000/authenticate`）。

### 3. 备份原 apiserver manifest

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

### 4. 启用 webhook 认证（切换 apiserver manifest）

```sh
sudo cp /Volumes/mac_data/code/go_code/101/module6/authn-webhook/specs/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

等待 kubelet 重建 apiserver Pod。

### 5. 配置 kubeconfig 的 user token

编辑 `~/.kube/config`，增加一个 user（示例名 `mfanjie`）：

```yaml
- name: mfanjie
  user:
    token: <YOUR_TOKEN>
```

> 说明：本仓库示例实现把 token 当作 GitHub Personal Access Token 来验证用户信息。

### 6. 验证

```sh
kubectl get pods --user mfanjie
```

如果认证通过，你会看到以该用户名身份发起的请求。

## 常见问题

- 认证服务不可达：apiserver 会返回 401 或出现认证相关日志。
- token 没权限：认证通过但鉴权失败会返回 403（RBAC 问题，不是认证问题）。

## 回滚

```sh
sudo cp ~/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 Token Webhook 认证进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **检查 kube-apiserver 配置**
   - 验证 `--authentication-token-webhook-config-file` 参数是否正确配置
   - 检查 webhook 配置文件是否存在

2. **检查 webhook 配置文件**
   - 验证 webhook 配置文件格式正确
   - 检查 webhook 服务地址配置

3. **检查 webhook 服务状态**
   - 验证 webhook 服务是否运行
   - 检查 webhook 服务的健康状态

4. **测试 webhook 认证**
   - 使用有效的 token 访问 API Server
   - 验证认证是否成功（HTTP 200）
   - 测试无效 token 是否被拒绝（HTTP 401）

5. **测试认证服务响应**
   - 验证 webhook 服务正确响应 TokenReview 请求
   - 检查返回的用户信息和认证状态

#### 预期结果

- kube-apiserver 正确配置 webhook 认证参数
- webhook 配置文件格式正确
- webhook 服务正常运行
- 有效 token 可以成功认证
- 无效 token 被正确拒绝
- webhook 服务正确返回用户信息

#### 验证输出示例

```
==========================================
Lab 04 - Token Webhook 认证验证
==========================================

1. 检查 kube-apiserver 配置
------------------------------------------
未找到 authentication-token-webhook 配置

2. 检查 webhook 配置文件
------------------------------------------
webhook 配置文件不存在

3. 检查认证服务是否运行
------------------------------------------
认证服务未运行

4. 检查认证服务端口
------------------------------------------
端口 3000 未监听

5. 测试 webhook 服务
------------------------------------------
测试 /authenticate 端点:
Webhook 服务无响应

6. 检查 kube-apiserver 日志中的认证信息
------------------------------------------
未找到相关日志

7. 检查 kubeconfig 中的用户配置
------------------------------------------
未找到 webhook 用户配置

==========================================
验证完成
==========================================

注意：
- 如果 webhook 认证未启用，需要先运行 switch_apiserver_to_webhook.sh
- 如果认证服务未运行，需要先启动 authn-webhook 服务
- 验证步骤：
  1. 启动认证服务
  2. 配置 webhook 文件
  3. 修改 kube-apiserver 配置
  4. 配置 kubeconfig 用户
  5. 使用 kubectl --user <username> 测试

Token Webhook 认证关键点：
- kube-apiserver 通过 webhook 服务进行认证
- webhook 服务接收 TokenReview 请求
- webhook 服务返回认证结果和用户信息
- 支持外部认证系统集成
- 认证通过后，鉴权阶段决定资源访问权限
```

**注意**：当前集群未配置 Token Webhook 认证。kube-apiserver 未启用 `--authentication-token-webhook-config-file` 参数，认证服务未运行，webhook 配置文件不存在。如需验证此实验，需要：
1. 启动 authn-webhook 认证服务
2. 创建 webhook 配置文件
3. 在 kube-apiserver manifest 中添加 `--authentication-token-webhook-config-file` 参数
4. 配置 kubeconfig 中的用户 token
5. 重启 kube-apiserver Pod

### 关键验证点

**当前验证结果**：
- [ ] kube-apiserver 未配置 `--authentication-token-webhook-config-file` 参数
- [ ] webhook 配置文件不存在
- [ ] webhook 服务未运行
- [ ] 端口 3000 未监听
- [ ] 无法进行 token 认证测试

**完整验证需要**：
- [x] kube-apiserver 正确配置 `--authentication-token-webhook-config-file` 参数
- [x] webhook 配置文件格式正确
- [x] webhook 服务正常运行
- [x] 有效 token 可以成功认证
- [x] 无效 token 被正确拒绝
- [x] webhook 服务正确返回用户信息
- [x] 认证流程正常工作

