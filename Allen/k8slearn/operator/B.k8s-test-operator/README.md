# B. k8s_test App Operator（发布型 Operator）

## 目标

- 用一个 CRD（建议命名 `K8sTest`）声明式管理一整套 `k8s_test`：
  - `etcd`
  - `user-service` / `product-service` / `trade-service` / `web-service`
  - 相关 `ConfigMap` / `Service` / `Ingress`
- 支持最小可用能力：
  - 安装（create）
  - 升级（update：镜像 tag / 副本数）
  - 卸载（delete：由 OwnerReference 级联清理）

---

## 前置

- 已完成 A：Tenant Operator（因为 B 需要一个稳定的 namespace 边界、以及统一的 imagePullSecret 策略）

---

## 快速入口（按顺序执行）

1. [01. 设计与范围](01.design.MD)
2. [02. 脚手架与工程初始化（Kubebuilder）](02.scaffold.MD)
3. [03. 实现控制器（最小可用版本）](03.controller-impl.MD)
4. [04. 构建镜像并部署到集群（阿里云镜像仓库）](04.deploy-by-aliyun-cr.MD)
5. [05. 验证、升级与卸载](05.verify-upgrade-uninstall.MD)
