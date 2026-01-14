# 故障排查指南 - 成为 Istio 侦探

> 快速定位和解决 Istio 问题

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Istio 出问题了怎么办？
如何快速定位问题？
如何使用 istioctl 排查问题？
```

**一句话精华**：
```
掌握 istioctl 命令和排查思路，
你就是 Istio 问题的福尔摩斯！
```

---

## 二、核心框架（知识骨架）

**核心观点**：
```
Istio 故障排查分为四步：
1. 观察现象（出了什么问题？）
2. 收集信息（用 istioctl 和 kubectl）
3. 分析原因（为什么会这样？）
4. 解决问题（怎么修复？）
```

**关键命令速查表**：

| 命令 | 作用 | 使用场景 |
|------|------|---------|
| istioctl analyze | 分析配置问题 | 配置不生效 |
| istioctl proxy-status | 查看代理状态 | Sidecar 异常 |
| istioctl proxy-config | 查看代理配置 | 路由不生效 |
| kubectl logs -c istio-proxy | 查看 Sidecar 日志 | 流量问题 |
| kubectl describe | 查看资源详情 | Pod 启动失败 |

---

## 三、常见问题排查（实战版）

### 【问题1：Sidecar 没有注入】

**现象**：
```bash
# Pod 只有 1 个容器，没有 istio-proxy
kubectl get pods
# NAME                     READY   STATUS    RESTARTS   AGE
# myapp-xxx                1/1     Running   0          1m
#                          ↑
#                    只有1个容器，应该是2个
```

**排查步骤**：

**步骤1：检查命名空间标签**
```bash
# 检查命名空间是否启用了自动注入
kubectl get namespace -L istio-injection

# 如果没有 enabled 标签，添加它
kubectl label namespace default istio-injection=enabled
```

**步骤2：检查 Pod 是否重建**
```bash
# Sidecar 注入只对新创建的 Pod 生效
# 需要重建 Pod
kubectl rollout restart deployment myapp
```

**步骤3：检查 Webhook**
```bash
# 检查 Sidecar 注入 Webhook 是否正常
kubectl get mutatingwebhookconfigurations

# 应该能看到 istio-sidecar-injector
```

**解决方案**：
```bash
# 1. 启用自动注入
kubectl label namespace default istio-injection=enabled

# 2. 重建 Pod
kubectl rollout restart deployment myapp

# 3. 验证
kubectl get pods
# 应该看到 2/2 Running
```

---

### 【问题2：流量路由不生效】

**现象**：
```bash
# 配置了 VirtualService，但流量还是随机分配
# 期望：90% 流量到 v1，10% 到 v2
# 实际：流量随机分配
```

**排查步骤**：

**步骤1：检查配置是否生效**
```bash
# 使用 istioctl analyze 检查配置
istioctl analyze

# 输出示例（有问题）：
# Error [IST0101] (VirtualService reviews) Referenced host not found: "reviews"
```

**步骤2：检查 DestinationRule**
```bash
# VirtualService 引用的 subset 必须在 DestinationRule 中定义
kubectl get destinationrule reviews -o yaml

# 检查是否定义了 v1 和 v2 subset
```

**步骤3：检查代理配置**
```bash
# 查看 Envoy 的路由配置
istioctl proxy-config routes <pod-name>

# 查看 Envoy 的 cluster 配置
istioctl proxy-config clusters <pod-name>
```

**解决方案**：
```yaml
# 1. 确保 DestinationRule 定义了 subset
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2

---
# 2. VirtualService 引用正确的 subset
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
```

---

### 【问题3：mTLS 连接失败】

**现象**：
```bash
# 服务 A 调用服务 B 失败
# 错误：upstream connect error or disconnect/reset before headers
```

**排查步骤**：

**步骤1：检查 mTLS 状态**
```bash
# 检查服务的 mTLS 状态
istioctl authn tls-check <pod-name> <service-name>

# 输出示例：
# HOST:PORT                                  STATUS     SERVER     CLIENT     AUTHN POLICY
# reviews.default.svc.cluster.local:9080     CONFLICT   mTLS       HTTP       default/
#                                            ↑
#                                      服务端要求 mTLS，客户端用 HTTP
```

**步骤2：检查 PeerAuthentication**
```bash
# 检查是否有冲突的 PeerAuthentication
kubectl get peerauthentication --all-namespaces

# 检查详情
kubectl get peerauthentication <name> -o yaml
```

**步骤3：检查 Sidecar 日志**
```bash
# 查看客户端 Sidecar 日志
kubectl logs <client-pod> -c istio-proxy | grep -i tls

# 查看服务端 Sidecar 日志
kubectl logs <server-pod> -c istio-proxy | grep -i tls
```

**解决方案**：
```yaml
# 方案1：统一使用 STRICT 模式
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---
# 方案2：使用 PERMISSIVE 模式（过渡期）
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE  # 允许 mTLS 和明文
```

---

### 【问题4：Pod 启动失败】

**现象**：
```bash
# Pod 一直处于 Init 或 CrashLoopBackOff 状态
kubectl get pods
# NAME                     READY   STATUS                  RESTARTS   AGE
# myapp-xxx                0/2     Init:CrashLoopBackOff   3          2m
```

**排查步骤**：

**步骤1：查看 Pod 事件**
```bash
# 查看 Pod 的事件
kubectl describe pod myapp-xxx

# 常见错误：
# - Failed to pull image
# - Init container failed
# - Liveness probe failed
```

**步骤2：查看容器日志**
```bash
# 查看应用容器日志
kubectl logs myapp-xxx -c myapp

# 查看 istio-init 容器日志
kubectl logs myapp-xxx -c istio-init

# 查看 istio-proxy 容器日志
kubectl logs myapp-xxx -c istio-proxy
```

**步骤3：检查资源限制**
```bash
# 检查节点资源
kubectl top nodes

# 检查 Pod 资源请求
kubectl get pod myapp-xxx -o yaml | grep -A 5 resources
```

**解决方案**：
```bash
# 1. 如果是镜像拉取失败
# 检查镜像地址和拉取策略

# 2. 如果是 istio-init 失败
# 检查是否有 NET_ADMIN 权限
kubectl get pod myapp-xxx -o yaml | grep -i securityContext

# 3. 如果是资源不足
# 增加节点资源或减少资源请求
```

---

### 【问题5：访问日志没有输出】

**现象**：
```bash
# 查看 Sidecar 日志，没有访问日志
kubectl logs myapp-xxx -c istio-proxy
# 只有启动日志，没有访问日志
```

**排查步骤**：

**步骤1：检查访问日志配置**
```bash
# 检查 Istio 配置
kubectl get configmap istio -n istio-system -o yaml | grep accessLogFile

# 如果没有配置或为空，说明访问日志未启用
```

**步骤2：启用访问日志**
```bash
# 方法1：重新安装 Istio 时启用
istioctl install --set profile=demo \
  --set meshConfig.accessLogFile=/dev/stdout -y

# 方法2：修改现有配置
kubectl edit configmap istio -n istio-system
# 添加：
# accessLogFile: /dev/stdout
```

**步骤3：重启 Pod**
```bash
# 配置修改后需要重启 Pod
kubectl rollout restart deployment myapp
```

**解决方案**：
```bash
# 启用访问日志
istioctl install --set profile=demo \
  --set meshConfig.accessLogFile=/dev/stdout -y

# 重启应用
kubectl rollout restart deployment myapp

# 验证
kubectl logs myapp-xxx -c istio-proxy
# 应该能看到访问日志
```

---

## 四、istioctl 命令大全

### 【分析和诊断】

```bash
# 分析配置问题
istioctl analyze
istioctl analyze --namespace default
istioctl analyze --all-namespaces

# 查看代理状态
istioctl proxy-status
istioctl proxy-status <pod-name>

# 查看版本
istioctl version
```

### 【代理配置】

```bash
# 查看所有配置
istioctl proxy-config all <pod-name>

# 查看路由配置
istioctl proxy-config routes <pod-name>
istioctl proxy-config routes <pod-name> --name <route-name>

# 查看 cluster 配置
istioctl proxy-config clusters <pod-name>
istioctl proxy-config clusters <pod-name> --fqdn <service-fqdn>

# 查看 listener 配置
istioctl proxy-config listeners <pod-name>

# 查看 endpoint 配置
istioctl proxy-config endpoints <pod-name>
istioctl proxy-config endpoints <pod-name> --cluster <cluster-name>

# 查看 secret 配置
istioctl proxy-config secrets <pod-name>
```

### 【认证和授权】

```bash
# 检查 mTLS 状态
istioctl authn tls-check <pod-name>
istioctl authn tls-check <pod-name> <service-name>

# 查看认证策略
kubectl get peerauthentication --all-namespaces
kubectl get requestauthentication --all-namespaces

# 查看授权策略
kubectl get authorizationpolicy --all-namespaces
```

### 【实验性功能】

```bash
# 查看 Envoy 统计信息
istioctl experimental envoy-stats <pod-name>

# 查看指标
istioctl experimental metrics <pod-name>

# 描述 Pod
istioctl experimental describe pod <pod-name>
```

---

## 五、排查思路总结

**排查流程图**：
```
问题出现
    ↓
观察现象（什么不正常？）
    ↓
收集信息
    ├─ kubectl get/describe（K8s 层面）
    ├─ istioctl analyze（配置层面）
    ├─ istioctl proxy-status（代理层面）
    └─ kubectl logs（日志层面）
    ↓
分析原因
    ├─ 配置错误？
    ├─ 网络问题？
    ├─ 权限问题？
    └─ 资源问题？
    ↓
解决问题
    ├─ 修改配置
    ├─ 重启 Pod
    └─ 调整资源
    ↓
验证解决
```

**黄金法则**：
1. **先看日志**：80% 的问题日志里都有答案
2. **用 istioctl analyze**：配置问题一查就知道
3. **检查 Sidecar**：没有 Sidecar 什么都不管用
4. **验证配置**：配置写了不代表生效了
5. **重启试试**：有时候重启就好了（但要知道为什么）

---

## 六、金句收藏

```
"日志是你的好朋友，不看日志就排查，那是瞎猜"

"istioctl analyze 是你的第一道防线，用它！"

"Sidecar 没注入，一切都是空谈"

"配置不生效？先检查 DestinationRule"

"mTLS 问题？先看 PeerAuthentication"

"排查问题就像破案，证据（日志）最重要"
```

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-08
- 基于 Istio 版本：1.20+
- 适用对象：Istio 用户、运维人员
