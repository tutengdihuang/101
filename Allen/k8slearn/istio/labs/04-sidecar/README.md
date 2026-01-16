# 实验四：Sidecar 流量劫持原理

> 深入理解 Envoy Sidecar 如何劫持和转发流量

## 实验目标

- 理解 iptables 流量劫持机制
- 掌握 istioctl proxy-config 命令
- 学会分析 Envoy 配置

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        Pod                                   │
│  ┌─────────────┐                      ┌─────────────┐       │
│  │   应用容器   │ ←──── iptables ────→ │   Envoy     │       │
│  │  (nginx)    │       流量劫持        │  (Sidecar)  │       │
│  └─────────────┘                      └─────────────┘       │
│        ↑                                    ↑               │
│        │                                    │               │
│   localhost:80                         15001/15006          │
└─────────────────────────────────────────────────────────────┘
```

## 流量路径

### 出站流量（Client → Server）

```
1. 应用发起请求
2. iptables 劫持到 15001 端口
3. Envoy virtualOutbound listener 处理
4. 根据目标地址选择 listener (0.0.0.0_80)
5. 根据 route 选择 cluster
6. 根据 endpoint 选择目标 Pod
7. iptables 放行（uid 1337）
8. 请求发送到目标 Pod
```

### 入站流量（Server 接收）

```
1. 请求到达 Pod
2. iptables 劫持到 15006 端口
3. Envoy virtualInbound listener 处理
4. 转发到本地应用（localhost:80）
```

## 实验步骤

### 1. 部署测试应用

```bash
kubectl create ns sidecar
kubectl label ns sidecar istio-injection=enabled
kubectl apply -f nginx.yaml -n sidecar
kubectl apply -f toolbox.yaml -n sidecar
```

### 2. 查看 Envoy 配置

```bash
# 获取 Pod 名称
TOOLBOX=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')
NGINX=$(kubectl get pod -l app=nginx -n sidecar -o jsonpath='{.items[0].metadata.name}')

# 查看 cluster（上游服务）
istioctl pc cluster -n sidecar $TOOLBOX

# 查看 listener（监听器）
istioctl pc listener -n sidecar $TOOLBOX

# 查看 route（路由）
istioctl pc route -n sidecar $TOOLBOX

# 查看 endpoint（端点）
istioctl pc endpoint -n sidecar $TOOLBOX
```

### 3. 分析出站流量

```bash
# 查看 15001 端口的 listener（出站入口）
istioctl pc listener -n sidecar $TOOLBOX --port 15001 -o json

# 查看 80 端口的 listener
istioctl pc listener -n sidecar $TOOLBOX --port 80 -o json

# 查看 80 端口的 route
istioctl pc route -n sidecar $TOOLBOX --name=80

# 查看 nginx 服务的 endpoint
istioctl pc endpoint -n sidecar $TOOLBOX | grep nginx
```

### 4. 查看 iptables 规则

```bash
# 获取 toolbox 容器的 PID
TOOLBOX_PID=$(kubectl get pod $TOOLBOX -n sidecar -o jsonpath='{.status.containerStatuses[0].containerID}' | cut -d'/' -f3)

# 在节点上查看 iptables 规则（需要 root 权限）
# nsenter -t <PID> -n iptables-save
```

### 5. 查看 Sidecar 日志

```bash
# 查看 Envoy 访问日志
kubectl logs -f $TOOLBOX -n sidecar -c istio-proxy
```

## 核心配置解析

### iptables 规则

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

### Envoy Listener

```
15001 (virtualOutbound) → 出站流量入口
15006 (virtualInbound)  → 入站流量入口
0.0.0.0_80              → HTTP 流量处理
```

### Envoy 访问日志格式

```
[%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
%RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT% %DURATION%
%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%"
"%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%" "%UPSTREAM_HOST%"
```

## istioctl proxy-config 命令

| 命令 | 说明 |
|------|------|
| `istioctl pc cluster` | 查看上游服务 |
| `istioctl pc listener` | 查看监听器 |
| `istioctl pc route` | 查看路由 |
| `istioctl pc endpoint` | 查看端点 |
| `istioctl pc secret` | 查看证书 |

## 清理

```bash
kubectl delete ns sidecar
```
