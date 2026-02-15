# Lab 01 - Static Token 认证（kube-apiserver --token-auth-file）

## 目标

- 在 kubeadm 静态 Pod 部署场景下，为 kube-apiserver 开启 `--token-auth-file`
- 使用 `curl` 携带 `Bearer Token` 直接访问 apiserver REST API

## 对应来源

- 本仓库：`module6/basic-auth/1.basic-auth.MD`
- 本仓库：`module6/basic-auth/static-token.csv`
- 本仓库：`module6/basic-auth/kube-apiserver.yaml`
- 训练营：模块六（API Server）-> 认证插件（静态 Token 文件）

## 前置条件

- 你有一套 kubeadm 安装的集群（控制平面节点可 SSH）
- kube-apiserver 以静态 Pod 形式运行（`/etc/kubernetes/manifests/kube-apiserver.yaml`）
- 你清楚控制平面节点 IP（本文用 `192.168.34.2`）

## 实验步骤

### 1. 准备静态 token 文件

在控制平面节点上：

```sh
sudo mkdir -p /etc/kubernetes/auth
sudo cp /path/to/static-token.csv /etc/kubernetes/auth/static-token
```

示例 token 行（CSV）：

```text
cncamp-token,cncamp,1000,"group1,group2,group3"
```

### 2. 备份原 kube-apiserver 静态 Pod manifest

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

### 3. 启用 `--token-auth-file`

把以下参数加入 kube-apiserver 命令行（或使用本仓库示例 manifest）：

- `--token-auth-file=/etc/kubernetes/auth/static-token`

如果你采用“替换 manifest”的方式：

```sh
sudo cp /path/to/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

kubelet 会自动重建 apiserver Pod（可能需要等待几十秒）。

### 4. 使用静态 token 访问 API

```sh
curl https://192.168.34.2:6443/api/v1/namespaces/default \
  -H "Authorization: Bearer cncamp-token" \
  -k
```

你应该能拿到 namespace 的 JSON 结果。

## 自测问题

- 如果 `--token-auth-file` 写错路径，apiserver 会出现什么症状？你怎么定位？
- 认证通过后，接下来哪个阶段会决定你能否 `list pods`？（提示：鉴权）

## 清理/回滚

```sh
sudo cp ~/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 Static Token 认证进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **检查 kube-apiserver 配置**
   - 验证 `--token-auth-file` 参数是否正确配置
   - 检查静态 token 文件是否存在

2. **测试 token 认证**
   - 使用 curl 携带 Bearer Token 访问 API Server
   - 验证认证是否成功（HTTP 200）
   - 测试无效 token 是否被拒绝（HTTP 401）

3. **验证 token 权限**
   - 测试有权限的 API 调用（如获取 namespace）
   - 测试无权限的 API 调用（如获取 pods，如果未授权）

#### 预期结果

- 使用有效 token 访问 API 返回 HTTP 200 和正确的 JSON 数据
- 使用无效 token 访问 API 返回 HTTP 401 Unauthorized
- 认证通过后，鉴权阶段决定资源访问权限

#### 验证输出示例

```
==========================================
Lab 01 - Static Token 认证验证
==========================================

1. 检查 kube-apiserver 静态 Pod 状态
------------------------------------------
NAME                        READY   STATUS    RESTARTS   AGE
kube-apiserver-k8s-master   1/1     Running   1          31d

2. 检查 kube-apiserver 配置
------------------------------------------
未找到 token-auth-file 配置

3. 检查静态 token 文件是否存在
------------------------------------------
静态 token 文件不存在

4. 检查静态 token 文件内容
------------------------------------------
无法读取 token 文件

5. 测试使用静态 token 访问 API
------------------------------------------
使用 Token: ...
未找到有效的 token

==========================================
验证完成
==========================================
```

**注意**：当前集群未配置 Static Token 认证。如需验证此实验，需要：
1. 创建静态 token 文件 `/etc/kubernetes/auth/static-token`
2. 在 kube-apiserver manifest 中添加 `--token-auth-file` 参数
3. 重启 kube-apiserver Pod

### 关键验证点

**当前验证结果**：
- [x] kube-apiserver 静态 Pod 运行正常
- [ ] kube-apiserver 未配置 `--token-auth-file` 参数
- [ ] 静态 token 文件不存在
- [ ] 无法进行 token 认证测试

**完整验证需要**：
- [ ] kube-apiserver 正确配置 `--token-auth-file` 参数
- [ ] 静态 token 文件格式正确（CSV 格式）
- [ ] 有效 token 可以成功认证
- [ ] 无效 token 被正确拒绝
- [ ] 认证通过后，鉴权阶段控制资源访问权限

