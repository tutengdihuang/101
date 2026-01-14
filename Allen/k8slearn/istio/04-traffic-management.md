# 流量管理 - 指挥交通的艺术

> 让流量按你的意愿流动

## 流量管理的核心

Istio 的流量管理就像城市的交通指挥系统。想象你是交通指挥官，你需要：
- 决定车辆走哪条路（路由）
- 控制每条路的车流量（权重）
- 设置等待时间上限（超时）
- 失败了自动换条路（重试）
- 路况太差就封路（熔断）

这一切都通过两个核心资源实现：
- **VirtualService**：定义流量路由规则（红绿灯）
- **DestinationRule**：定义目的地策略（路标）

---

## VirtualService - 流量的导航仪

VirtualService 告诉流量应该往哪走，就像导航仪给你规划路线。

**基本结构**：
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:           # 目标服务
  - reviews
  http:            # HTTP 路由规则
  - match:         # 匹配条件
    - headers:
        end-user:
          exact: jason
    route:         # 路由目的地
    - destination:
        host: reviews
        subset: v2
  - route:         # 默认路由
    - destination:
        host: reviews
        subset: v1
```

**常用匹配条件**：

```yaml
# 基于请求头
match:
- headers:
    end-user:
      exact: jason      # 精确匹配
    cookie:
      regex: "^user=.*" # 正则匹配

# 基于 URI
match:
- uri:
    exact: /productpage  # 精确匹配
- uri:
    prefix: /api/        # 前缀匹配

# 基于查询参数
match:
- queryParams:
    version:
      exact: v2
```

---

## DestinationRule - 目的地的规则手册

DestinationRule 定义到达目的地后的策略，包括子集定义、负载均衡、熔断等。

VirtualService 告诉你去哪，DestinationRule 告诉你到了怎么办。就像导航告诉你去北京，DestinationRule 告诉你北京有三个机场，到了机场怎么排队。

**基本结构**：
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:                # 子集定义
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
  trafficPolicy:          # 流量策略
    loadBalancer:
      simple: ROUND_ROBIN
```

**负载均衡策略**：
| 策略 | 说明 |
|------|------|
| ROUND_ROBIN | 轮询（默认） |
| RANDOM | 随机 |
| LEAST_CONN | 最少连接 |

---

## 实战：灰度发布

灰度发布是最常用的流量管理场景。新版本上线，先让少数用户试用，没问题再逐步扩大。

**步骤1：定义子集**
```yaml
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
```

**步骤2：配置 90-10 分流**
```yaml
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

**步骤3：逐步调整比例**
```
第一阶段：90% v1 / 10% v2
第二阶段：70% v1 / 30% v2
第三阶段：50% v1 / 50% v2
第四阶段：0% v1 / 100% v2
```

传统方式需要改代码、重新部署，Istio 只需要改配置，秒级生效，随时可以回滚。


---

## 实战：基于请求头的路由

根据请求头的内容，把流量路由到不同版本。常用于 A/B 测试、内测等场景。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        x-test-user:
          exact: "true"
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

测试：
```bash
# 普通请求，走 v1
curl http://$GATEWAY_URL/productpage

# 带测试头的请求，走 v2
curl -H "x-test-user: true" http://$GATEWAY_URL/productpage
```

应用场景：
- 测试人员访问测试版本
- 内部员工访问内部版本
- VIP 用户访问特殊版本

---

## 实战：超时和重试

服务调用有时候会慢或者失败，通过超时和重试提高可靠性。

```yaml
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
    timeout: 3s           # 超时时间
    retries:
      attempts: 3         # 重试次数
      perTryTimeout: 1s   # 每次重试超时
      retryOn: 5xx,reset,connect-failure
```

**重试条件**：
| 条件 | 说明 |
|------|------|
| 5xx | 服务端错误 |
| reset | 连接被重置 |
| connect-failure | 连接失败 |
| gateway-error | 网关错误 |

这就像点外卖：等太久就超时，失败了自动换一家重试。不需要改代码，Istio 自动处理。

---

## 实战：故障注入

故障注入用于测试系统的健壮性，就像消防演习，在可控环境下发现问题。

**注入延迟**：
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 7s    # 延迟 7 秒
    route:
    - destination:
        host: ratings
        subset: v1
```

**注入错误**：
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      abort:
        percentage:
          value: 50       # 50% 请求
        httpStatus: 500   # 返回 500
    route:
    - destination:
        host: ratings
        subset: v1
```

故障注入的价值：
- 发现系统的薄弱环节
- 验证应急预案是否有效
- 提高团队的应急能力

---

## 实战：熔断器

熔断器保护系统不被拖垮。当服务不健康时，自动切断流量，给它恢复的时间。

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5     # 连续 5 次错误
      interval: 10s               # 检测间隔
      baseEjectionTime: 30s       # 熔断时间
      maxEjectionPercent: 100
  subsets:
  - name: v1
    labels:
      version: v1
```

熔断器就像保险丝：
- 没有熔断器：服务 B 挂了，服务 A 一直调用，最终 A 也被拖垮
- 有熔断器：服务 B 连续挂了 5 次，自动熔断 30 秒，A 快速失败，不会被拖垮

---

## 核心要点总结

| 功能 | 配置 | 作用 |
|------|------|------|
| 灰度发布 | VirtualService.weight | 按比例分流 |
| 条件路由 | VirtualService.match | 按条件分流 |
| 超时 | VirtualService.timeout | 设置超时时间 |
| 重试 | VirtualService.retries | 失败自动重试 |
| 故障注入 | VirtualService.fault | 测试系统健壮性 |
| 熔断 | DestinationRule.outlierDetection | 保护系统不崩溃 |

记住两个核心资源：
- **VirtualService** = 红绿灯，控制流量走向
- **DestinationRule** = 路标，定义目的地策略

---

## 下一步

流量管理让你控制了流量的走向，但安全同样重要：

- 如何保护服务间的通信安全？
- 如何实现服务间的加密通信？
- 如何控制服务的访问权限？

下一篇《安全管理 - 给服务穿上防弹衣》将为你详细讲解！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-14
- 基于 Istio 版本：1.20+

---

**上一篇**：[第一个 Istio 应用 - BookInfo 示例](03-bookinfo-demo.md)  
**下一篇**：[安全管理 - 给服务穿上防弹衣](05-security.md)
