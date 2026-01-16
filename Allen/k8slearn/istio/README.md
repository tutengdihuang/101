# Istio 服务网格学习指南

> 让微服务之间的通信变得优雅而可控

## 学习路径

```
01 概览 → 02 安装 → 03 流量管理 → 04 安全管理 → 05 可观测性 → 06 Sidecar 原理
```

## 文档导航

| 文档 | 内容 | 时长 |
|------|------|------|
| [01-istio-overview.md](01-istio-overview.md) | Istio 是什么、架构、核心概念 | 15分钟 |
| [02-istio-installation.md](02-istio-installation.md) | 安装 Istio、验证部署 | 20分钟 |
| [04-traffic-management.md](04-traffic-management.md) | Gateway、VirtualService、金丝雀发布 | 30分钟 |
| [05-security.md](05-security.md) | mTLS、PeerAuthentication、AuthorizationPolicy | 30分钟 |
| [06-sidecar-deep-dive.md](06-sidecar-deep-dive.md) | Sidecar 流量劫持原理、iptables、Envoy 配置 | 30分钟 |

## 实验目录

基于训练营课件（模块十二、模块十四）整理的实验：

```
labs/
├── 01-http-gateway/          # HTTP Gateway 实验（module12/1.http-gw）
├── 02-l7-routing/            # 七层路由实验（module12/2.l7）
├── 03-https-gateway/         # HTTPS Gateway 实验（module12/3.https-gw）
├── 04-sidecar/               # Sidecar 原理实验（module12/4.sidecar）
├── 05-canary/                # 金丝雀发布实验（module12/5.canary）
├── 06-fault-injection/       # 故障注入实验（module12/6.fault-inject）
├── 07-tracing/               # 分布式追踪实验（module12/tracing）
├── 08-authentication/        # 认证实验 mTLS（module14/authentication）
└── 09-authorization/         # 授权实验（module14/authorization）
```

每个实验包含：
- `README.md` - 实验说明和步骤
- `*.yaml` - Kubernetes/Istio 配置文件
- `run.sh` - 一键运行脚本

## 核心概念速查

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| 服务网格 | 管理服务间通信的基础设施层 | 城市的交通管理系统 |
| Sidecar | 每个服务旁边的代理 | 每辆车的导航仪 |
| VirtualService | 流量路由规则 | 红绿灯 |
| DestinationRule | 目的地策略 | 路标 |
| Gateway | 服务网格入口 | 城市大门 |
| PeerAuthentication | 服务间认证 | 门禁系统 |
| AuthorizationPolicy | 访问控制 | 权限管理 |

## 快速开始

```bash
# 1. 安装 Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
cp bin/istioctl /usr/local/bin
istioctl install --set profile=demo -y

# 2. 启用 Sidecar 自动注入
kubectl create ns demo
kubectl label ns demo istio-injection=enabled

# 3. 运行第一个实验
cd labs/01-http-gateway
chmod +x run.sh
./run.sh
```

## 实验快速索引

### 流量管理（模块十二）

| 实验 | 核心知识点 | 命令 |
|------|-----------|------|
| 01-http-gateway | Gateway + VirtualService | `cd labs/01-http-gateway && ./run.sh` |
| 02-l7-routing | URI 匹配 + URL 重写 | `cd labs/02-l7-routing && ./run.sh` |
| 03-https-gateway | TLS 终止 + 证书管理 | `cd labs/03-https-gateway && ./run.sh` |
| 04-sidecar | iptables + Envoy 配置 | `cd labs/04-sidecar && ./run.sh` |
| 05-canary | Header 路由 + 金丝雀发布 | `cd labs/05-canary && ./run.sh` |
| 06-fault-injection | 超时 + 重试 + 故障注入 | 参考 README |
| 07-tracing | Jaeger + 分布式追踪 | 参考 README |

### 安全管理（模块十四）

| 实验 | 核心知识点 | 命令 |
|------|-----------|------|
| 08-authentication | mTLS + PeerAuthentication | `cd labs/08-authentication && ./run.sh` |
| 09-authorization | AuthorizationPolicy | `cd labs/09-authorization && ./run.sh` |

## 金句收藏

> "服务网格就像城市的交通管理系统，让每辆车（服务）都能安全、高效地到达目的地"

> "VirtualService 是红绿灯，DestinationRule 是路标"

> "mTLS 就像给每个服务发了一张身份证，只有持证上岗才能通信"

---

**版本信息**：基于 Istio 1.12+ | 参考：模块十二、模块十四训练营课件
