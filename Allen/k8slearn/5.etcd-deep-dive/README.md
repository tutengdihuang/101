# etcd 深入理解 - Kubernetes 的"大脑"

> 没有 etcd，Kubernetes 就是一具没有记忆的躯壳

## 前言

如果把 Kubernetes 比作一个人，那么：
- API Server 是嘴巴（接收指令）
- Controller Manager 是手脚（执行动作）
- Scheduler 是大脑的决策区（调度决策）
- **etcd 是记忆中枢**（存储所有状态）

etcd 挂了，整个集群就"失忆"了。所以理解 etcd 对于运维 K8s 至关重要。

---

## 什么是 etcd？

etcd 是一个**分布式键值存储系统**，具有以下特点：

| 特性 | 说明 | 类比 |
|------|------|------|
| 强一致性 | 所有节点数据一致 | 银行账本，每个分行数据必须一致 |
| 高可用 | 多节点部署，容忍故障 | 多个备份硬盘 |
| Watch 机制 | 监听数据变化 | 订阅通知 |
| 事务支持 | 原子操作 | 要么全成功，要么全失败 |
| 版本控制 | 保留历史版本 | Git 版本管理 |

---

## etcd 在 K8s 中的角色

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes 集群                         │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ API Server  │───▶│    etcd     │◀───│ API Server  │     │
│  └─────────────┘    │  (3 节点)   │    └─────────────┘     │
│         │           └─────────────┘           │             │
│         ▼                                     ▼             │
│  ┌─────────────┐                      ┌─────────────┐       │
│  │ Controller  │                      │  Scheduler  │       │
│  │  Manager    │                      │             │       │
│  └─────────────┘                      └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

etcd 存储了 K8s 的所有数据：
- Pod、Deployment、Service 等对象定义
- ConfigMap、Secret 配置
- 节点信息、命名空间
- RBAC 权限配置
- ...

---

## 目录

| 章节 | 内容 | 核心知识点 |
|------|------|-----------|
| [01-etcd 基础操作](01-etcd-basics.md) | 安装、启动、基本命令 | put/get/watch/delete |
| [02-etcd 数据模型](02-data-model.md) | 版本、Revision、Lease | MVCC、TTL |
| [03-etcd 集群部署](03-cluster-setup.md) | 高可用集群搭建 | Raft 共识、成员管理 |
| [04-etcd 备份恢复](04-backup-restore.md) | 数据备份与灾难恢复 | snapshot、restore |
| [05-etcd 运维实践](05-operations.md) | 监控、告警、碎片整理 | alarm、defrag、compact |
| [06-K8s 中的 etcd](06-etcd-in-k8s.md) | K8s 集群中的 etcd 操作 | 查看 K8s 数据 |

---

## 学习路径

```
[etcd 基础] → [数据模型] → [集群部署] → [备份恢复] → [运维实践] → [K8s 中的 etcd]
     ↑
   你在这里
```

---

## 环境准备

本教程提供两种实验环境：

### 方式一：Docker 快速启动（推荐）

```bash
# 启动单节点 etcd
docker run -d --name etcd-demo \
  -p 2379:2379 \
  -p 2380:2380 \
  registry.aliyuncs.com/google_containers/etcd:3.5.0-0 \
  /usr/local/bin/etcd \
  --advertise-client-urls http://0.0.0.0:2379 \
  --listen-client-urls http://0.0.0.0:2379

# 进入容器
docker exec -it etcd-demo sh
```

### 方式二：本地安装

```bash
# 下载 etcd
ETCD_VER=v3.5.0
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzvf etcd.tar.gz
cd etcd-${ETCD_VER}-linux-amd64
sudo cp etcd etcdctl /usr/local/bin/
```

---

## 实验脚本

本教程提供完整的实验脚本，位于 `scripts/` 目录：

```
scripts/
├── 01-basic-ops.sh          # 基础操作实验
├── 02-lease-demo.sh         # Lease 租约实验
├── 03-watch-demo.sh         # Watch 监听实验
├── 04-cluster-start.sh      # 集群启动脚本
├── 05-backup.sh             # 备份脚本
├── 06-restore.sh            # 恢复脚本
└── 07-k8s-etcd-ops.sh       # K8s etcd 操作
```

---

## 版本信息

- 文档版本：v1.0
- 创建日期：2026-01-15
- etcd 版本：3.5.x
- 适用对象：K8s 运维人员、想深入理解 K8s 存储层的开发者

---

## 参考资料

- [etcd 官方文档](https://etcd.io/docs/v3.5/)
- [How etcd works with and without Kubernetes](https://learnk8s.io/etcd-kubernetes)

---

**开始学习**：[etcd 基础操作](01-etcd-basics.md)
