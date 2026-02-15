# Kubernetes 对象设计完全指南

> 从 Pod 到 Deployment，从 ConfigMap 到探针，掌握 K8s 核心对象

## 前言

Kubernetes 的强大之处在于它的声明式 API 和丰富的对象类型。但面对 Pod、Deployment、Service、ConfigMap、StatefulSet 这么多概念，很多人会感到困惑：

- Pod 和 Deployment 有什么区别？
- ConfigMap 有几种使用方式？
- 探针是干什么的？为什么需要它？
- StatefulSet 和 Deployment 什么时候用哪个？

本指南将用生活化的比喻和大量实验，帮你彻底搞懂 Kubernetes 的核心对象。

---

## 一句话总结

**Kubernetes 对象就像乐高积木，每种积木有特定用途，组合起来构建复杂应用**。

| 对象 | 作用 | 生活比喻 |
|------|------|---------|
| Pod | 运行容器的最小单元 | 一个房间（可以住一个人或一家人） |
| Deployment | 管理 Pod 的副本和更新 | 物业公司（管理多个房间） |
| Service | 提供稳定的访问入口 | 小区门牌号（不管住户换不换） |
| ConfigMap | 存储配置信息 | 公告栏（大家都能看到的信息） |
| Secret | 存储敏感信息 | 保险箱（加密存储） |
| StatefulSet | 管理有状态应用 | 带编号的房间（1号房、2号房） |

---

## 目录

| 章节 | 内容 | 核心知识点 |
|------|------|-----------|
| [01-Pod 基础](01-pod-basics.md) | Pod 的本质和使用 | Pod 结构、多容器 Pod、生命周期 |
| [02-Deployment 详解](02-deployment.md) | 无状态应用管理 | 副本管理、滚动更新、回滚 |
| [03-ConfigMap 与 Secret](03-configmap-secret.md) | 配置管理 | 创建方式、挂载方式、热更新 |
| [04-探针与健康检查](04-probes.md) | 应用健康管理 | Liveness、Readiness、Startup |
| [05-Service 与网络](05-service.md) | 服务发现与负载均衡 | ClusterIP、NodePort、Endpoints |
| [06-StatefulSet](06-statefulset.md) | 有状态应用管理 | 稳定标识、有序部署、持久存储 |

---

## 学习路径

```
[Pod 基础] → [Deployment] → [ConfigMap] → [探针] → [Service] → [StatefulSet]
     ↑
   你在这里
```

建议按顺序学习，每个章节都有：
- 📖 **理论讲解**：用生活化的比喻解释概念
- 🔬 **动手实验**：亲手操作，加深理解
- 📝 **YAML 详解**：逐行解释配置文件
- 💡 **最佳实践**：生产环境的经验总结

---

## 环境准备

```bash
# 检查 kubectl 是否可用
kubectl version

# 检查集群状态
kubectl cluster-info

# 检查节点状态
kubectl get nodes
```

---

## 版本信息

- 文档版本：v1.0
- 创建日期：2026-01-15
- 适用 Kubernetes 版本：1.20+
- 适用对象：有 Docker 基础，想深入学习 K8s 的开发者和运维人员

---

**开始学习**：[Pod 基础 - Kubernetes 的最小单元](01-pod-basics.md)
