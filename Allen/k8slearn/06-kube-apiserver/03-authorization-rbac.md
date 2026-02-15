# 03 - 鉴权（Authorization）与 RBAC：你能做什么？

> 目标：把 RBAC 讲深讲透——不仅会写 Role/Binding，还要能解释“为什么这么设计”，以及遇到 403 如何定位。

## 训练营要点（提炼总结）

训练营把鉴权的本质说成一句话：**把请求的属性（用户/资源/动作/namespace…）和策略对比，匹配就放行，否则 403**。

它强调 Kubernetes 鉴权只看这些“属性维度”：
- `user / group / extra`
- API、请求方法（get/post/update/patch/delete…）与路径（/api…）
- 请求资源/子资源（resource/subresource）
- namespace
- API Group

并列出常见鉴权插件：
- ABAC
- RBAC
- Webhook
- Node

## RBAC vs ABAC：为什么 RBAC 成为默认答案

训练营给了一个非常实际的理由：

- ABAC 概念很美（Attribute-based），但在 K8s 的实现中：
  - 难管理、难理解
  - 需要 master 节点文件系统权限
  - 修改策略通常需要重启 apiserver 才生效

- RBAC 的优势是“像管理资源一样管理权限”：
  - 你可以用 `kubectl` 或 Kubernetes API 直接配置
  - 权限对象本身就是集群资源（可审计、可 GitOps）
  - 可以把“管理权限”的权限授权给特定管理员团队

一句话：**ABAC 更像手工改配置文件；RBAC 更像用声明式资源管理权限。**

## RBAC 的核心模型（who / what / how）

训练营用一句“新解”很经典：

- **who（谁）**：Subject（User / Group / ServiceAccount）
- **what（什么资源）**：APIGroup + Resource + Subresource
- **how（怎么操作）**：Verb（get/list/watch/create/update/patch/delete…）

对应到对象：

- Role / ClusterRole：定义一组规则（rules）
- RoleBinding / ClusterRoleBinding：把规则绑定给主体（subjects）

### Role vs ClusterRole

- **Role**：只在某个 namespace 内有效
- **ClusterRole**：集群范围有效（或被 RoleBinding 引用来在某 namespace 内授权）

训练营给的典型使用建议：
- namespace 内资源优先 Role
- 集群级资源/非资源类 API（如 `/healthz`）用 ClusterRole

## 容易踩坑的细节（训练营“运营陷阱”提炼）

### 坑 1：verb 缺失导致线上 403

训练营举了一个特别常见的事故：
- 研发把 `update` 改成了 `patch`
- 本地测试环境 OK（可能走了 cluster-admin）
- 上生产不 work
- 原因：RBAC 里没有 `patch` 权限

**结论**：写权限策略时，动词必须和你的代码行为一致。

### 坑 2：CRD/聚合 API 的权限忘了配

训练营案例：
- 研发创建 CRD 并开发控制器
- 上生产后控制器读不到 CRD

**结论**：CRD 是集群级资源，权限配置要提前补齐。

### 坑 3：角色/绑定对象爆炸，导致 apiserver 负担变重

训练营提到：
- 大量 Role/RoleBinding 会降低鉴权效率
- 建议“权限源代码化”（用 spec/仓库驱动），避免临时 edit 越积越多

## 排障：403 Forbidden 的最短路径

当你遇到 403，按这个顺序排：

1. **先确认是否 401**
   - 401 是认证问题（上一章）
   - 403 才是 RBAC

2. 用 `kubectl auth can-i` 快速判断

```sh
kubectl auth can-i get pods -n default --as <user>
```

3. 如果是 ServiceAccount：

```sh
kubectl auth can-i list pods -n default --as system:serviceaccount:<ns>:<sa>
```

4. 定位到底缺哪条 rule
   - 缺资源？缺 apiGroup？还是缺 verb（尤其 patch/watch）

## 实践

- [Lab 03 RBAC](labs/03-rbac/README.md)

> 提示：这个 lab 目前用的是 `cluster-admin` 绑定示例（用于理解最短链路）。如果你想做“生产风格”，建议再加一个最小 Role + RoleBinding 的练习。

## 自测问题

- `RoleBinding` 可以引用 `ClusterRole` 吗？这样授权范围是什么？
- 为什么 `watch` 在很多 controller 场景里是必须的？
- 你如何判断一个 403 是“缺权限”还是“namespace 写错/资源名写错”？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**上一篇**：[02 认证机制](02-authentication.md)
**下一篇**：[04 准入控制](04-admission-control.md)

