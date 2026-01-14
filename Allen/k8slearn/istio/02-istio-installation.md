# Istio 安装指南 - 让魔法生效

> 三步安装 Istio，开启服务网格之旅

## 安装前的准备

在开始之前，确保你已经有一个运行中的 Kubernetes 集群，并且对 kubectl 命令有基本了解。如果你还没有 K8s 集群，建议先搭建一个，可以使用 minikube、kind 或者云服务商提供的 K8s 服务。

安装 Istio 其实很简单，就像装修房子一样：下载材料 → 选择套餐 → 开始装修 → 验收。

---

## 第一步：下载 Istio

从官网下载 Istio 安装包到本地，就像去建材市场买装修材料。

**方法1：使用官方脚本（推荐）**
```bash
# 下载最新版本的 Istio
curl -L https://istio.io/downloadIstio | sh -
```

**方法2：下载指定版本**
```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
```

下载后的目录结构：
```
istio-1.20.0/
├── bin/istioctl          # 命令行工具
├── manifests/            # 安装清单
├── samples/              # 示例应用
└── tools/                # 其他工具
```

添加 istioctl 到 PATH：
```bash
cd istio-1.20.0
export PATH=$PWD/bin:$PATH
istioctl version
```


---

## 第二步：选择安装 Profile

Istio 提供了多种安装配置（Profile），就像装修套餐，不同套餐适合不同场景。

| Profile | 包含组件 | 适用场景 | 资源占用 |
|---------|---------|---------|---------|
| demo | Istiod + Ingress + Egress + 可观测性 | 学习、演示 | 高 |
| default | Istiod + Ingress Gateway | 生产环境 | 中 |
| minimal | 仅 Istiod | 资源受限环境 | 低 |
| empty | 无 | 自定义安装 | 无 |

**选择建议**：
- 学习阶段：用 **demo**，功能全开，方便体验
- 生产环境：用 **default**，功能够用，资源合理
- 资源紧张：用 **minimal**，只装核心组件

查看可用的 Profile：
```bash
istioctl profile list
istioctl profile dump demo  # 查看详细配置
```

---

## 第三步：安装 Istio

选好套餐，开始装修！

**安装 demo profile（推荐学习使用）**：
```bash
istioctl install --set profile=demo -y

# 输出示例：
# ✔ Istio core installed
# ✔ Istiod installed
# ✔ Ingress gateways installed
# ✔ Egress gateways installed
# ✔ Installation complete
```

**安装 default profile（推荐生产使用）**：
```bash
istioctl install --set profile=default -y
```

**自定义安装**：
```bash
# 安装 demo，但禁用 egress gateway
istioctl install --set profile=demo \
  --set components.egressGateways[0].enabled=false -y

# 启用访问日志
istioctl install --set profile=default \
  --set meshConfig.accessLogFile=/dev/stdout -y
```

---

## 第四步：启用 Sidecar 自动注入

Istio 的魔力来自 Sidecar。给命名空间打个标签，以后部署的 Pod 就会自动注入 Sidecar，就像给房间贴个"智能家居"标签，放进去的设备自动配置。

```bash
# 启用自动注入
kubectl label namespace default istio-injection=enabled

# 验证
kubectl get namespace -L istio-injection
```

测试自动注入：
```bash
kubectl create deployment nginx --image=nginx
kubectl get pods
# NAME         READY   STATUS    RESTARTS   AGE
# nginx-xxx    2/2     Running   0          10s
#              ↑
#        2个容器 = 应用 + Sidecar
```

---

## 第五步：验证安装

装修完了要验房，确保一切正常。

**检查 Pod 状态**：
```bash
kubectl get pods -n istio-system
# 所有 Pod 应该是 Running 状态
```

**检查配置**：
```bash
istioctl analyze
# ✔ No validation issues found
```

**检查版本**：
```bash
istioctl version
# client version: 1.20.0
# control plane version: 1.20.0
```

验收清单：
- ✅ 所有 istio-system 的 Pod 都是 Running
- ✅ istioctl version 能看到 control plane version
- ✅ istioctl analyze 没有报错
- ✅ 部署的应用 Pod 有 2 个容器

---

## 常见问题排查

**问题1：安装卡住不动**
```bash
# 查看安装进度
kubectl get pods -n istio-system -w
kubectl describe pod <pod-name> -n istio-system
```

**问题2：Pod 一直 Pending**
```bash
# 资源不足，使用 minimal profile
istioctl install --set profile=minimal -y
```

**问题3：需要重装**
```bash
istioctl uninstall --purge -y
kubectl delete namespace istio-system
istioctl install --set profile=demo -y
```

---

## 核心要点总结

1. **下载 Istio**：`curl -L https://istio.io/downloadIstio | sh -`
2. **选择 Profile**：demo（学习）、default（生产）、minimal（资源受限）
3. **安装 Istio**：`istioctl install --set profile=demo -y`
4. **启用自动注入**：`kubectl label namespace default istio-injection=enabled`
5. **验证安装**：`kubectl get pods -n istio-system` + `istioctl analyze`

口诀：**下载 → 选套餐 → 安装 → 启用注入 → 验收**

---

## 下一步

Istio 已经安装好了，接下来通过 BookInfo 示例体验 Istio 的神奇之处！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-14
- 基于 Istio 版本：1.20+

---

**上一篇**：[Istio 概览 - 服务网格的魔法世界](01-istio-overview.md)  
**下一篇**：[第一个 Istio 应用 - BookInfo 示例](03-bookinfo-demo.md)
