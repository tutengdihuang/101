# A. Tenant Operator（治理型 Operator）

## 目标

- 通过一个 `Tenant` CRD 让 Operator 自动完成：
  - 创建/维护 `Namespace`
  - 创建/维护 `ResourceQuota`
  - 创建/维护 `RoleBinding`（绑定集群级 `ClusterRole`）
- 用 **Deployment 方式**把 controller 部署到集群（阿里云私有镜像仓库）
- 全流程命令采用“命令返回模式”（`sshpass` + `KUBECONFIG=/etc/kubernetes/admin.conf`）

---

## 目录说明

- 代码工程：`../tenant-operator/`
- 本目录仅放 A 阶段的**完整教程**（与 B 阶段完全分离）

---

## 快速入口（按顺序执行）

1. [01. 概览与接口](01.overview.MD)
2. [02. 部署到集群（阿里云镜像仓库）](02.deploy-by-aliyun-cr.MD)
3. [03. 验证与卸载](03.verify-and-uninstall.MD)
