# Helm 学习指南 - Kubernetes 的包管理器

> 让 Kubernetes 应用部署变得像安装软件一样简单

## 一句话精华

**Helm 就像 Kubernetes 的 App Store，让你一键安装、升级、回滚应用，不用再手写一堆 YAML 文件。**

## 学习路径

```
01 概览 → 02 基础操作 → 03 Chart 开发 → 04 模板语法 → 05 实战案例
```

## 文档导航

| 文档 | 内容 | 时长 |
|------|------|------|
| [01-helm-overview.md](01-helm-overview.md) | Helm 是什么、为什么需要 Helm | 10分钟 |
| [02-helm-basics.md](02-helm-basics.md) | 安装、仓库管理、基本命令 | 20分钟 |
| [03-chart-development.md](03-chart-development.md) | Chart 结构、创建自己的 Chart | 30分钟 |
| [04-template-syntax.md](04-template-syntax.md) | 模板语法、内置对象、函数 | 30分钟 |
| [05-best-practices.md](05-best-practices.md) | 最佳实践、常见问题 | 20分钟 |

## 实验目录

```
labs/
├── 01-install-chart/         # 安装第一个 Chart
├── 02-create-chart/          # 创建自己的 Chart
├── 03-template-demo/         # 模板语法实战
├── 04-upgrade-rollback/      # 升级和回滚
└── 05-real-world/            # 真实项目案例
```

## 核心概念速查

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| Helm | Kubernetes 的包管理器 | App Store |
| Chart | 应用的安装包 | 安装程序 |
| Release | 安装后的实例 | 已安装的应用 |
| Repository | Chart 仓库 | 应用商店 |
| Values | 配置参数 | 安装选项 |

## 快速开始

```bash
# 1. 安装 Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 2. 添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 3. 安装第一个应用
helm install my-nginx bitnami/nginx

# 4. 查看安装的应用
helm list

# 5. 卸载应用
helm uninstall my-nginx
```

## 为什么学 Helm？

### 没有 Helm 的痛苦

```bash
# 部署一个应用需要：
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f configmap.yaml
kubectl apply -f ingress.yaml
kubectl apply -f secret.yaml
# ... 还有更多

# 升级？手动改每个文件
# 回滚？祈祷你有备份
# 多环境？复制粘贴一堆文件
```

### 有了 Helm 的优雅

```bash
# 安装
helm install myapp ./mychart

# 升级
helm upgrade myapp ./mychart

# 回滚
helm rollback myapp

# 多环境
helm install myapp ./mychart -f prod-values.yaml
```

## 金句收藏

> "Helm 就像 Kubernetes 的 apt-get，让你告别 YAML 地狱"

> "Chart 是配方，Release 是做出来的菜"

> "没有 Helm 之前，部署应用像搬砖；有了 Helm，部署应用像点外卖"

---

**版本信息**：基于 Helm 3.x | 适合 Kubernetes 用户
