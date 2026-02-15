# 02 - 认证（Authentication）：你是谁？

> 目标：把“认证插件有哪些、什么时候用、怎么排查”说清楚，并落到可操作的实验。

## 训练营要点（提炼总结）

训练营（模块六）对认证的关键结论是：

- **开启 TLS 时，请求必须先认证**
- Kubernetes 支持**多种认证机制**，并且可以**同时启用多个认证插件**
  - 只要**有一个**认证插件通过即可
- 认证成功后会产生 `username / groups` 等信息，交给下一步“鉴权”使用
- 认证失败通常返回 **HTTP 401**

## 常见认证方式（从易到难）

### 1) 静态 Token 文件（Static Token File）

**适用场景**：学习/演示/小型环境；不建议生产大规模使用（难管理、难审计）。

**训练营提到的要点**：
- apiserver 启动参数：`--token-auth-file=SOMEFILE`
- 文件为 CSV：`token,username,userid,"group1,group2"`

**本仓库对应**：
- `module6/basic-auth/static-token.csv`
- `module6/basic-auth/kube-apiserver.yaml`（示例将 token 文件 mount 到 `/etc/kubernetes/auth/` 并开启参数）

**实践**：
- [Lab 01 静态 Token](labs/01-static-token/README.md)

### 2) X509 客户端证书（Client Certificate）

**适用场景**：生产常用（强身份、与 kubeconfig/证书体系兼容）。

**训练营提到的要点**：
- apiserver 参数：`--client-ca-file=SOMEFILE`
- 证书中的：
  - `CN` 常被当作用户名
  - `O` 常被当作 group

**本仓库对应**：
- `module6/basic-auth/x509.MD`（CSR -> approve -> 导出证书 -> 配置 kubeconfig）

**实践**：
- [Lab 02 X509 用户证书](labs/02-x509-user/README.md)

### 3) Basic Auth / 静态密码文件（了解为主）

训练营提到：可以用 `--basic-auth-file=SOMEFILE`（CSV 格式），但现代 Kubernetes 通常不推荐。

### 4) ServiceAccount

训练营提到：
- SA token 会挂载到 Pod 内固定路径（典型：`/run/secrets/kubernetes.io/serviceaccount`）
- 用于 Pod 内组件访问 apiserver

> 本模块（06）当前 labs 未单独做 SA 实验；建议后续在 RBAC 章节扩展一个“SA + RoleBinding”的小 lab。

### 5) Webhook Token 认证（TokenReview）

**适用场景**：企业对接统一身份（LDAP/OIDC/自建 auth service），希望把 token 校验交给外部系统。

训练营提到：
- apiserver 参数：
  - `--authentication-token-webhook-config-file=...`
  - `--authentication-token-webhook-cache-ttl=...`（默认 2 分钟）

**本仓库对应**：
- `module6/authn-webhook/`（示例实现 TokenReview webhook）

**实践**：
- [Lab 04 Token Webhook](labs/04-authn-webhook/README.md)

## 排障思路（避免把 401/403 搞混）

- **401 Unauthorized**：通常是认证没过（token/cert 不对、apiserver 没启用该认证方式、webhook 不可达）
- **403 Forbidden**：通常是认证过了，但 RBAC 没授权（下一章解决）

建议顺手用：

```sh
kubectl auth can-i get pods -n default --as <user>
```

来判断“有没有权限”。

## 自测问题

- 为什么 Kubernetes 可以同时启用多个认证插件？这会带来什么风险/收益？
- Webhook 认证服务挂了，会对集群造成什么影响？如何避免把外部认证服务压垮？（训练营里提到了 rate limit/circuit break 的思路）

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**上一篇**：[01 kube-apiserver 概览](01-apiserver-overview.md)
**下一篇**：[03 RBAC 鉴权](03-authorization-rbac.md)

