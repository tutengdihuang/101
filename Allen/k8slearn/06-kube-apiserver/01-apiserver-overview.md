# 01 - kube-apiserver 概览：它到底在 Kubernetes 里做什么

> 目标：建立“一个请求从进来到落盘”的整体心智模型。

## kube-apiserver 是什么

一句话：**kube-apiserver 是 Kubernetes 的统一入口 + 访问控制闸门 + 状态写入枢纽**。

训练营（模块六）里把它的职责概括得很清晰：
- 提供集群管理的 REST API（认证/授权/校验/状态变更）
- 作为控制平面各组件与数据存储（etcd）之间的通信枢纽（**只有 apiserver 直接写 etcd**）

## 一条请求的“流水线”

Kubernetes API 请求大体会经历：

1. **认证（Authentication）**：你是谁？
2. **鉴权（Authorization）**：你能做什么？
3. **准入（Admission）**：这次请求内容是否合规？是否需要补默认值/注入内容？
4. **存储（Storage）**：通过 apiserver 的存储层写入/读取 etcd

训练营里强调：认证失败通常返回 **HTTP 401**；鉴权失败返回 **HTTP 403**。

## 核心概念（用类比快速记）

- apiserver = “公司前台 + 门禁 + 审批中心”
- etcd = “档案室”（强一致的系统记录）
- Controller/Scheduler/Kubelet = “各部门员工”（都要走前台申请/查询信息）

你只要记住：**任何人想改集群状态，都得先过 apiserver 这道门。**

## 与本仓库 module6 的对应关系

本仓库 `module6/` 正好覆盖了训练营这条流水线里的关键环节：

- **认证**：
  - 静态 Token：`module6/basic-auth/`
  - X509 证书：`module6/basic-auth/x509.MD`
  - Webhook TokenReview：`module6/authn-webhook/`

- **鉴权**：
  - RBAC 示例：`module6/rbac/`

- **准入**：
  - MutatingWebhook 示例：`module6/mutatingwebhook/`

- **配额（准入插件中的典型能力）**：
  - ResourceQuota：`module6/quota/quota.yaml`

## 实践（建议顺序）

- 先做“最直观的认证”
  - [Lab 01 静态 Token](labs/01-static-token/README.md)
  - [Lab 02 X509 用户证书](labs/02-x509-user/README.md)

- 再做“有了身份以后怎么授权”
  - [Lab 03 RBAC](labs/03-rbac/README.md)

- 最后做“准入如何改/拦请求”
  - [Lab 05 MutatingWebhook](labs/05-mutatingwebhook/README.md)
  - [Lab 06 ResourceQuota](labs/06-resourcequota/README.md)

## 自测问题

- 为什么说“只有 apiserver 直接操作 etcd”？其他组件为什么不能绕过它？
- 你如何区分一次失败是认证问题（401）还是鉴权问题（403）？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**下一篇**：[02 认证机制](02-authentication.md)
