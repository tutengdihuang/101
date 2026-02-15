# 06 - kube-apiserver（理论 + 实践）

> 本章目标：用“训练营模块六”的理论框架，把 apiserver 的关键机制讲深讲透，并用本仓库的 `labs/` 做可复现实验。

## 目录（理论）

1. [kube-apiserver 概览](01-apiserver-overview.md)
2. [认证 Authentication](02-authentication.md)
3. [鉴权与 RBAC Authorization](03-authorization-rbac.md)
4. [准入控制 Admission Control](04-admission-control.md)
5. [限流与 APF（Priority & Fairness）](05-rate-limit-and-apf.md)
6. [高可用与运维](06-ha-and-ops.md)

## 实验（实践 labs）

- [Lab 01 静态 Token 认证](labs/01-static-token/README.md)
- [Lab 02 X509 客户端证书认证](labs/02-x509-user/README.md)
- [Lab 03 RBAC 权限](labs/03-rbac/README.md)
- [Lab 04 Token Webhook 认证](labs/04-authn-webhook/README.md)
- [Lab 05 Mutating Webhook](labs/05-mutatingwebhook/README.md)
- [Lab 06 ResourceQuota 配额](labs/06-resourcequota/README.md)

## 学习路径（建议）

- **阶段 1：搭骨架（30-60 分钟）**
  - 读 `01`，明确“请求流水线：认证→鉴权→准入→存储”
- **阶段 2：认证落地（1-2 小时）**
  - 读 `02` + 做 Lab 01/02
- **阶段 3：权限体系落地（1-2 小时）**
  - 读 `03` + 做 Lab 03
- **阶段 4：策略与治理（1-2 小时）**
  - 读 `04/05/06` + 做 Lab 05/06

## 理论来源（不做粗暴复制，仅用于提炼）

- `Allen/k8S训练营/模块六：Kubernetes 控制平面组件：API Server.pdf`
- `Allen/k8S训练营/*.PanD`（百度文档链接快捷方式，仅作为参考链接）

## 版本信息

- 文档版本：v1.0
- 创建日期：2026-01-18
- 最后更新：2026-01-18
