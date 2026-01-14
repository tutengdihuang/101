# 安全管理 - 给服务穿上防弹衣

> 让服务间通信变得安全可靠

## 安全管理的三层防护

Istio 的安全管理就像银行的安保系统，有三层防护：

1. **mTLS**：服务间加密通信（加密通话）
2. **PeerAuthentication**：对等认证（验证身份）
3. **AuthorizationPolicy**：授权策略（访问控制）

三层防护，让服务固若金汤。

---

## mTLS - 服务间的加密通话

mTLS（双向 TLS）让服务间的通信自动加密，而且双方都要验证身份。

**没有 mTLS 的服务通信**：
```
服务 A："喂，我是服务 A"
服务 B："好的，我是服务 B"
黑客："我在旁边偷听呢..."
```

**有 mTLS 的服务通信**：
```
服务 A："这是我的证书"
服务 B："验证通过，这是我的证书"
服务 A："验证通过，开始加密通话"
黑客："我听不懂他们在说什么..."
```

mTLS 的特点：
- **双向验证**：双方都要出示证书
- **自动加密**：通信内容自动加密
- **自动管理**：证书由 Istiod 自动签发和轮换，不需要人工干预

```
┌─────────────────────────────────────────────────────────┐
│                     Istiod (CA)                         │
│                   证书颁发机构                           │
│              自动签发、自动轮换证书                       │
└─────────────────────────────────────────────────────────┘
                        ↓ 证书下发
┌─────────────────────────────────────────────────────────┐
│  ┌──────────────┐          ┌──────────────┐            │
│  │   服务 A      │  mTLS   │   服务 B      │            │
│  │ ┌──────────┐ │ ←────→  │ ┌──────────┐ │            │
│  │ │  Envoy   │ │ 加密通信 │ │  Envoy   │ │            │
│  │ │ (证书)   │ │          │ │ (证书)   │ │            │
│  │ └──────────┘ │          │ └──────────┘ │            │
│  └──────────────┘          └──────────────┘            │
└─────────────────────────────────────────────────────────┘
```

---

## PeerAuthentication - 验证你是谁

PeerAuthentication 定义服务间通信的认证策略，决定是否强制使用 mTLS。

**三种模式**：

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| PERMISSIVE | 宽松模式，接受 mTLS 和明文 | 迁移过渡期 |
| STRICT | 严格模式，只接受 mTLS | 生产环境 |
| DISABLE | 禁用 mTLS | 特殊场景 |

这就像门禁系统：
- **PERMISSIVE**：有卡刷卡，没卡登记也能进（过渡期）
- **STRICT**：必须刷卡才能进（正式运营）
- **DISABLE**：随便进（不推荐）

**全局启用 STRICT 模式**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system  # 全局生效
spec:
  mtls:
    mode: STRICT
```

**命名空间级别配置**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

**服务级别配置**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: reviews-strict
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  mtls:
    mode: STRICT
```

配置优先级：服务 > 命名空间 > 全局


---

## AuthorizationPolicy - 控制谁能进

AuthorizationPolicy 定义访问控制策略，决定谁能访问谁。

PeerAuthentication 验证你是谁，AuthorizationPolicy 决定你能去哪。就像公司门禁：验证了你是员工，但不是所有地方你都能进。

**两种动作**：
| 动作 | 说明 |
|------|------|
| ALLOW | 允许访问（白名单） |
| DENY | 拒绝访问（黑名单） |

**允许特定服务访问**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-allow
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
```

这个配置的意思是：只有 productpage 服务能访问 reviews 服务。

**拒绝特定服务访问**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-deny
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/ratings"]
```

**基于请求属性的授权**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-request
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/reviews/*"]
```

这个配置更精细：只允许 productpage 用 GET 方法访问 /reviews/* 路径。

**默认拒绝所有**：
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}  # 空规则 = 拒绝所有
```

---

## 实战：启用全局 mTLS

**步骤1：先用 PERMISSIVE 模式过渡**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE
```

```bash
kubectl apply -f peer-authentication-permissive.yaml
```

**步骤2：验证 mTLS 工作**
```bash
istioctl x describe pod <productpage-pod>
# 查看 Effective PeerAuthentication
```

**步骤3：确认所有服务都有 Sidecar 后，切换到 STRICT**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

**步骤4：验证 STRICT 模式**
```bash
# 从没有 Sidecar 的 Pod 访问，应该失败
kubectl run test --image=curlimages/curl --rm -it -- \
  curl http://productpage:9080/productpage
# 因为没有证书，无法建立 mTLS 连接
```

**注意**：直接启用 STRICT 可能导致没有 Sidecar 的服务无法通信，所以要先用 PERMISSIVE 过渡。

---

## 实战：配置服务间访问控制

假设我们要实现：只有 productpage 能访问 reviews，其他服务不能访问。

**步骤1：创建默认拒绝策略**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}
```

**步骤2：允许 productpage 访问 reviews**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-allow-productpage
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
```

**步骤3：允许 reviews 访问 ratings**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ratings-allow-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
```

**步骤4：允许 Ingress Gateway 访问 productpage**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-allow-ingress
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
```

验证：
```bash
# 正常访问
curl http://$GATEWAY_URL/productpage  # 成功

# 从其他 Pod 访问 reviews
kubectl exec -it <some-pod> -- curl http://reviews:9080/reviews/0
# RBAC: access denied
```

---

## 核心要点总结

| 资源 | 作用 | 类比 |
|------|------|------|
| mTLS | 服务间加密通信 | 加密电话 |
| PeerAuthentication | 定义 mTLS 模式 | 门禁系统 |
| AuthorizationPolicy | 定义访问控制 | 权限管理 |

**安全配置的最佳实践**：
1. 先用 PERMISSIVE 模式过渡
2. 确保所有服务都有 Sidecar
3. 再切换到 STRICT 模式
4. 配置细粒度的访问控制

记住：**零信任 = 默认不信任 + 始终验证**

---

## 下一步

现在你已经掌握了 Istio 的流量管理和安全管理，接下来可以学习：

- 可观测性：如何监控服务的健康状态？
- 分布式追踪：如何追踪一个请求经过了哪些服务？
- 指标监控：如何查看服务的 QPS、延迟、错误率？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-14
- 基于 Istio 版本：1.20+

---

**上一篇**：[流量管理 - 指挥交通的艺术](04-traffic-management.md)
