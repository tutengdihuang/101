# Sidecar 深度解析 - 流量劫持的魔法

> 理解 Envoy Sidecar 如何劫持和转发流量

## Sidecar 是什么？

Sidecar 就像每辆车的导航仪，它不改变车本身，但能控制车的行驶路线。在 Istio 中，Sidecar 是一个 Envoy 代理，它被注入到每个 Pod 中，拦截所有进出 Pod 的流量。

```
┌─────────────────────────────────────────────────────────────┐
│                        Pod                                   │
│  ┌─────────────┐                      ┌─────────────┐       │
│  │   应用容器   │ ←──── iptables ────→ │   Envoy     │       │
│  │  (你的代码)  │       流量劫持        │  (Sidecar)  │       │
│  └─────────────┘                      └─────────────┘       │
│        ↑                                    ↑               │
│        │                                    │               │
│   localhost:80                         15001/15006          │
└─────────────────────────────────────────────────────────────┘
```

---

## 流量劫持原理

Istio 使用 iptables 规则劫持流量到 Envoy Sidecar。

### 出站流量（Client → Server）

```
1. 应用发起请求（curl nginx）
2. iptables 劫持到 15001 端口
3. Envoy virtualOutbound listener 处理
4. 根据目标地址选择 listener (0.0.0.0_80)
5. 根据 route 选择 cluster
6. 根据 endpoint 选择目标 Pod IP
7. iptables 放行（uid 1337 是 Envoy 用户）
8. 请求发送到目标 Pod
```

### 入站流量（Server 接收）

```
1. 请求到达 Pod
2. iptables 劫持到 15006 端口
3. Envoy virtualInbound listener 处理
4. 转发到本地应用（localhost:80）
```

---

## iptables 规则详解

```bash
# 出站流量劫持到 15001
-A OUTPUT -p tcp -j ISTIO_OUTPUT
-A ISTIO_OUTPUT -j ISTIO_REDIRECT
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001

# Envoy 自身流量放行（uid 1337）
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN

# 入站流量劫持到 15006
-A PREROUTING -p tcp -j ISTIO_INBOUND
-A ISTIO_INBOUND -p tcp -j REDIRECT --to-ports 15006
```

为什么 uid 1337 要放行？因为 Envoy 自己发出的请求不能再被劫持，否则会死循环。

---

## Envoy 配置结构

Envoy 的配置分为四个核心部分：

| 组件 | 说明 | 类比 |
|------|------|------|
| Listener | 监听器，接收流量 | 收费站入口 |
| Route | 路由规则，决定去哪 | 导航路线 |
| Cluster | 上游服务集群 | 目的地城市 |
| Endpoint | 具体的服务实例 | 具体地址 |

### 查看 Envoy 配置

```bash
# 获取 Pod 名称
POD=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')

# 查看 Listener
istioctl pc listener -n sidecar $POD

# 查看 Route
istioctl pc route -n sidecar $POD

# 查看 Cluster
istioctl pc cluster -n sidecar $POD

# 查看 Endpoint
istioctl pc endpoint -n sidecar $POD
```

---

## 关键 Listener

| 端口 | 名称 | 作用 |
|------|------|------|
| 15001 | virtualOutbound | 出站流量入口 |
| 15006 | virtualInbound | 入站流量入口 |
| 15090 | Prometheus | 指标暴露 |
| 15021 | Health Check | 健康检查 |

### 出站流量处理流程

```bash
# 1. 查看 15001 listener
istioctl pc listener -n sidecar $POD --port 15001 -o json
# useOriginalDst: true，使用原始目标地址

# 2. 查看 80 端口 listener
istioctl pc listener -n sidecar $POD --port 80 -o json
# routeConfigName: "80"

# 3. 查看 route 80
istioctl pc route -n sidecar $POD --name=80
# 根据 Host 选择 cluster

# 4. 查看 cluster
istioctl pc cluster -n sidecar $POD | grep nginx
# outbound|80||nginx.sidecar.svc.cluster.local

# 5. 查看 endpoint
istioctl pc endpoint -n sidecar $POD | grep nginx
# 192.168.x.x:80  HEALTHY  OK  outbound|80||nginx.sidecar.svc.cluster.local
```

---

## Envoy 访问日志

默认日志格式：

```
[%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
%RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT% %DURATION%
%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%"
"%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
```

查看日志：

```bash
kubectl logs $POD -n sidecar -c istio-proxy -f
```

---

## 常用 istioctl 命令

| 命令 | 说明 |
|------|------|
| `istioctl pc cluster <pod>` | 查看上游服务 |
| `istioctl pc listener <pod>` | 查看监听器 |
| `istioctl pc route <pod>` | 查看路由 |
| `istioctl pc endpoint <pod>` | 查看端点 |
| `istioctl pc secret <pod>` | 查看证书 |
| `istioctl analyze` | 分析配置问题 |
| `istioctl x describe pod <pod>` | 描述 Pod 的 Istio 配置 |

---

## 实验：观察流量劫持

```bash
# 1. 创建命名空间
kubectl create ns sidecar
kubectl label ns sidecar istio-injection=enabled

# 2. 部署应用
kubectl apply -f labs/04-sidecar/nginx.yaml -n sidecar
kubectl apply -f labs/04-sidecar/toolbox.yaml -n sidecar

# 3. 查看 Envoy 配置
POD=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')
istioctl pc listener -n sidecar $POD
istioctl pc route -n sidecar $POD
istioctl pc cluster -n sidecar $POD
istioctl pc endpoint -n sidecar $POD | grep nginx

# 4. 测试访问并观察日志
kubectl exec -it $POD -n sidecar -c toolbox -- curl nginx
kubectl logs $POD -n sidecar -c istio-proxy --tail=5
```

---

## 核心要点

1. **流量劫持**：iptables 将流量劫持到 Envoy
2. **出站端口**：15001（virtualOutbound）
3. **入站端口**：15006（virtualInbound）
4. **配置结构**：Listener → Route → Cluster → Endpoint
5. **调试工具**：istioctl proxy-config

---

**版本信息**：基于 Istio 1.12+ | 参考：模块十二训练营课件
