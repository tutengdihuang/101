# Docker 核心技术完全指南

> 深入理解容器的底层原理，从 Namespace 到 Cgroups，从文件系统到网络

## 前言

你有没有想过，Docker 容器到底是怎么实现"隔离"的？为什么容器里的进程看不到宿主机的其他进程？为什么容器只能使用限定的 CPU 和内存？

如果你对这些问题感到好奇，那么这份指南就是为你准备的！

本指南将带你深入 Docker 的底层技术，理解容器的本质。学完之后，你会发现：**容器并不神秘，它只是 Linux 内核特性的巧妙组合**。

---

## 一句话总结

**容器 = Namespace（隔离）+ Cgroups（限制）+ OverlayFS（文件系统）**

就像把一个人关在一个房间里：
- **Namespace** = 房间的墙壁（看不到外面）
- **Cgroups** = 水电配额（限制资源使用）
- **OverlayFS** = 房间里的家具（独立的生活空间）

---

## 目录

| 章节 | 内容 | 核心知识点 |
|------|------|-----------|
| [01-容器技术概览](01-container-overview.md) | 容器的本质是什么？ | 容器 vs 虚拟机、三大核心技术 |
| [02-Namespace](02-namespace.md) | 隔离的魔法 | 8 种 Namespace、unshare、nsenter |
| [03-Cgroups](03-cgroups.md) | 资源的管家 | CPU 限制、内存限制、OOM |
| [04-OverlayFS](04-overlayfs.md) | 分层的文件系统 | 写时复制、白障文件、镜像分层 |
| [05-容器网络](05-container-network.md) | 连接的艺术 | veth pair、docker0、iptables |
| [06-镜像优化](06-image-optimization.md) | 让镜像更小更快 | 多阶段构建、Alpine、清理缓存 |

---

## 学习路径

```
[容器概览] → [Namespace] → [Cgroups] → [OverlayFS] → [网络] → [镜像优化]
     ↑
   你在这里
```

建议按顺序学习，每个章节都有：
- 📖 **理论讲解**：用生活化的比喻解释技术概念
- 🔬 **动手实验**：亲手操作，加深理解
- 💡 **思考题**：检验学习效果

---

## 核心概念速查

| 技术 | 作用 | 生活比喻 | 关键命令 |
|------|------|---------|---------|
| Namespace | 资源隔离 | 每个房间有独立的门牌号 | `unshare`, `nsenter`, `lsns` |
| Cgroups | 资源限制 | 每个房间的水电配额 | `/sys/fs/cgroup/` |
| OverlayFS | 分层文件系统 | 透明胶片叠加 | `mount -t overlay` |
| Veth Pair | 虚拟网络设备 | 两个房间之间的对讲机 | `ip link add type veth` |
| Bridge | 网络桥接 | 小区的交换机 | `brctl`, `docker0` |

---

## 环境准备

本指南的实验需要 Linux 环境（推荐 Ubuntu 20.04+）。

```bash
# 检查内核版本（需要 4.0+）
uname -r

# 检查 cgroups 支持
ls /sys/fs/cgroup/

# 检查 namespace 支持
ls /proc/self/ns/

# 检查 Docker 是否安装
docker version
```

---

## 学完能收获什么？

1. **理解容器本质**：知道容器不是虚拟机，而是被"关在笼子里"的进程
2. **掌握核心技术**：Namespace、Cgroups、OverlayFS 的原理和使用
3. **排查问题能力**：遇到容器问题时，知道从哪里入手
4. **优化镜像能力**：让镜像更小、构建更快、部署更安全

---

## 版本信息

- 文档版本：v1.0
- 创建日期：2026-01-15
- 适用对象：想深入理解容器原理的开发者和运维人员
- 前置知识：Linux 基础、Docker 基本使用

---

**开始学习**：[容器技术概览 - 容器的本质是什么？](01-container-overview.md)
