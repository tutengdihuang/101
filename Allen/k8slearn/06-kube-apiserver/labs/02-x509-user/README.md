# Lab 02 - X509 客户端证书认证（CSR -> approve -> kubeconfig）

## 目标

- 生成用户私钥与 CSR
- 在集群内创建 `CertificateSigningRequest` 并审批
- 从 CSR status 中导出证书
- 将用户凭据写入 kubeconfig，并通过 RBAC 授权后访问资源

## 对应来源

- 本仓库：`module6/basic-auth/x509.MD`
- 训练营：模块六（API Server）-> 认证插件（X509 客户端证书）

## 前置条件

- 已有管理员权限的 `kubectl`（能创建/approve CSR）
- 本地安装 `openssl`

## 实验步骤

### 1. 生成私钥与 CSR

```sh
openssl genrsa -out myuser.key 2048
openssl req -new -key myuser.key -out myuser.csr
```

注意：CSR 里的 `CN` 通常会被当作 username（例如 `myuser`），`O` 会被当作 group。

### 2. CSR base64 编码

```sh
cat myuser.csr | base64 | tr -d "\n"
```

### 3. 创建 Kubernetes CSR 对象

把上一步输出填入 `spec.request`：

```sh
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: myuser
spec:
  request: <BASE64_CSR>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
```

### 4. 审批 CSR

```sh
kubectl certificate approve myuser
```

### 5. 导出证书

```sh
kubectl get csr myuser -o jsonpath='{.status.certificate}' | base64 -d > myuser.crt
```

### 6. 写入 kubeconfig（新增用户凭据）

```sh
kubectl config set-credentials myuser \
  --client-key=myuser.key \
  --client-certificate=myuser.crt \
  --embed-certs=true
```

### 7. 给该用户授权（RBAC）

示例：在 `default` namespace 里给 `myuser` 一个 `developer` 角色。

```sh
kubectl create role developer \
  --verb=create --verb=get --verb=list --verb=update --verb=delete \
  --resource=pods

kubectl create rolebinding developer-binding-myuser \
  --role=developer \
  --user=myuser
```

### 8. 用该用户访问资源

```sh
kubectl get pods -n default --user myuser
```

## 常见误区

- CSR 没有 approve：`status.certificate` 为空。
- 授权缺少 `list`/`watch`/`get` 等 verb：会出现 `Forbidden`。

## 清理

```sh
kubectl delete csr myuser
kubectl delete rolebinding developer-binding-myuser -n default
kubectl delete role developer -n default
rm -f myuser.key myuser.csr myuser.crt
```

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 X509 客户端证书认证进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **生成用户私钥和 CSR**
   - 使用 OpenSSL 生成 2048 位 RSA 私钥
   - 创建证书签名请求（CSR），指定 CN（用户名）和 O（组）
   - 验证 CSR 生成成功

2. **创建 Kubernetes CSR 对象**
   - 将 CSR 内容进行 base64 编码
   - 创建 CertificateSigningRequest 资源
   - 设置 signerName 为 `kubernetes.io/kube-apiserver-client`
   - 设置证书有效期和用途

3. **审批 CSR**
   - 使用 `kubectl certificate approve` 批准证书请求
   - 验证 CSR 状态变为 Approved

4. **导出证书**
   - 从 CSR 对象的 status.certificate 字段导出证书
   - 进行 base64 解码得到 PEM 格式证书
   - 验证证书内容

5. **创建 kubeconfig**
   - 使用 `kubectl config set-credentials` 添加用户凭据
   - 设置 client-key 和 client-certificate
   - 验证 kubeconfig 配置正确

6. **配置 RBAC 权限**
   - 创建 Role 定义允许的 verbs 和 resources
   - 创建 RoleBinding 将 Role 绑定到用户
   - 验证权限配置

7. **测试用户访问**
   - 使用 `kubectl --user myuser` 访问资源
   - 测试有权限的操作（get、list pods）
   - 测试无权限的操作（delete、create pods）

#### 预期结果

- CSR 生成成功，包含正确的 CN 和 O
- CertificateSigningRequest 对象创建成功
- CSR 审批后状态变为 Approved
- 证书成功导出，包含正确的用户信息
- kubeconfig 正确配置用户凭据
- 有权限的操作成功执行
- 无权限的操作返回 Forbidden 错误

#### 验证输出示例

```
==========================================
Lab 02 - X509 客户端证书认证验证
==========================================

1. 生成用户私钥
------------------------------------------
Generating RSA private key, 2048 bit long modulus
私钥生成成功

2. 生成 CSR 请求
------------------------------------------
CSR 生成成功

3. 创建 Kubernetes CSR 对象
------------------------------------------
certificatesigningrequest.certificates.k8s.io/testuser created

4. 查看 CSR 状态
------------------------------------------
NAME       AGE   SIGNERNAME                                    REQUESTOR                  CONDITION
testuser   1s    kubernetes.io/kube-apiserver-client          kubernetes-admin           Pending

5. 审批 CSR
------------------------------------------
certificatesigningrequest.certificates.k8s.io/testuser approved

6. 查看 CSR 审批状态
------------------------------------------
NAME       AGE   SIGNERNAME                                    REQUESTOR                  CONDITION
testuser   2s    kubernetes.io/kube-apiserver-client          kubernetes-admin           Approved, Issued

7. 导出证书
------------------------------------------
证书导出成功
-rw-r--r-- 1 root root 0 Jan 24 13:32 .crt

8. 创建 RBAC Role
------------------------------------------
role.rbac.authorization.k8s.io/developer created

9. 创建 RoleBinding
------------------------------------------
rolebinding.rbac.authorization.k8s.io/developer-binding-testuser created

10. 验证用户权限
------------------------------------------
权限验证失败
error: could not stat client-certificate file testuser.crt: stat testuser.crt: no such file or directory

11. 清理测试资源
------------------------------------------
certificatesigningrequest.certificates.k8s.io "testuser" deleted
rolebinding.rbac.authorization.k8s.io "developer-binding-testuser" deleted
role.rbac.authorization.k8s.io/developer" deleted
清理完成

==========================================
验证完成
==========================================

X509 认证关键点：
- CN 字段作为用户名
- O 字段作为用户组
- 需要审批 CSR 才能获取证书
- 证书有效期由 expirationSeconds 控制
- 需要配合 RBAC 授权才能访问资源
```

**注意**：证书导出过程中存在问题，导出的证书文件大小为 0 字节，导致后续验证失败。需要检查证书导出命令和 base64 解码过程。

### 关键验证点

**当前验证结果**：
- [x] 私钥和 CSR 生成成功
- [x] CSR 包含正确的 CN（testuser）和 O（developers）
- [x] CertificateSigningRequest 对象创建成功
- [x] CSR 成功审批，状态变为 Approved, Issued
- [ ] 证书导出失败（文件大小为 0 字节）
- [ ] kubeconfig 配置失败
- [ ] Role 和 RoleBinding 创建成功
- [ ] 用户权限验证失败（证书文件不存在）

**完整验证需要**：
- [x] 私钥和 CSR 生成成功
- [x] CSR 包含正确的 CN（用户名）和 O（组）
- [x] CertificateSigningRequest 对象创建成功
- [x] CSR 成功审批，状态变为 Approved
- [ ] 证书成功导出，格式正确
- [ ] kubeconfig 正确配置用户凭据
- [x] Role 和 RoleBinding 创建成功
- [ ] 有权限的操作（get、list）成功执行
- [ ] 无权限的操作（delete）被正确拒绝
- [ ] 认证和鉴权流程正常工作

