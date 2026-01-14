# 第一个 Istio 应用 - BookInfo 示例

> 通过 BookInfo 示例，感受 Istio 的魔力

## BookInfo 是什么？

BookInfo 是 Istio 官方提供的示例应用，就像售楼处的样板房，让你在真实的微服务场景中体验 Istio 的各种功能。

它是一个在线书店应用，由 4 个微服务组成：

```
                    ┌─────────────────┐
                    │   productpage   │  ← 前端页面（Python）
                    │    用户入口      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
      ┌───────────┐  ┌───────────┐  ┌───────────┐
      │  details  │  │  reviews  │  │  reviews  │
      │  书籍详情  │  │    v1     │  │   v2/v3   │
      │  (Ruby)   │  │  纯文字    │  │  带星星    │
      └───────────┘  └───────────┘  └─────┬─────┘
                                          │
                                          ▼
                                   ┌───────────┐
                                   │  ratings  │
                                   │  评分服务  │
                                   │  (Node)   │
                                   └───────────┘
```

**reviews 服务有三个版本**，这是 BookInfo 最有趣的地方：
- **v1**：只显示文字评价，没有星星
- **v2**：显示文字评价 + 黑色星星
- **v3**：显示文字评价 + 红色星星

通过这三个版本，你可以体验 Istio 的灰度发布、流量路由等功能。

---

## 部署 BookInfo

**前提条件**：
```bash
# 确保 Istio 已安装
kubectl get pods -n istio-system

# 确保自动注入已启用
kubectl get namespace -L istio-injection
# 如果没有启用：
kubectl label namespace default istio-injection=enabled
```

**部署应用**：
```bash
cd istio-1.20.0
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

**验证部署**：
```bash
kubectl get pods
# NAME                              READY   STATUS    RESTARTS   AGE
# details-v1-xxx                    2/2     Running   0          2m
# productpage-v1-xxx                2/2     Running   0          2m
# ratings-v1-xxx                    2/2     Running   0          2m
# reviews-v1-xxx                    2/2     Running   0          2m
# reviews-v2-xxx                    2/2     Running   0          2m
# reviews-v3-xxx                    2/2     Running   0          2m
```

注意每个 Pod 都是 `2/2`，说明 Sidecar 已经注入成功。

**在集群内部测试**：
```bash
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -sS productpage:9080/productpage | head -20
```

---

## 配置 Gateway

应用部署好了，但外部还访问不了，需要配置 Gateway，就像给书店装个大门。

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

这个配置做了两件事：
1. **Gateway**：定义入口，监听 80 端口
2. **VirtualService**：定义路由，把 `/productpage` 路由到 productpage 服务

**获取访问地址**：
```bash
# 如果是 LoadBalancer 类型
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

# 如果是 NodePort 类型
export INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "访问地址: http://$GATEWAY_URL/productpage"
```

**验证访问**：
```bash
curl -s "http://$GATEWAY_URL/productpage" | head -20
# 或者在浏览器中访问
```


---

## 观察 Istio 的魔力

打开浏览器访问 `http://<GATEWAY_URL>/productpage`，多次刷新页面，你会发现一个有趣的现象：

- 第一次刷新：Book Reviews 区域只有文字，没有星星（v1）
- 第二次刷新：Book Reviews 区域有文字 + 黑色星星（v2）
- 第三次刷新：Book Reviews 区域有文字 + 红色星星（v3）
- 继续刷新：三个版本随机出现...

**为什么会这样？**

因为 reviews 服务有三个版本同时运行，而我们还没有配置流量规则，所以 Istio 把流量随机分配到三个版本。这就像书店有三个评价员轮流值班，顾客随机遇到不同的评价员。

查看 Sidecar 日志，可以看到流量确实被 Istio 接管了：
```bash
kubectl logs -l app=productpage -c istio-proxy --tail=10
```

---

## 配置流量路由

现在让我们用 Istio 控制流量走向。

**首先，定义服务的子集（版本）**：
```bash
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

这个配置告诉 Istio：reviews 服务有 v1、v2、v3 三个子集，分别对应不同的 Pod。

**场景1：所有流量都走 v1**
```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

刷新页面，你会发现每次都只有文字评价，没有星星了。所有流量都被路由到 v1！

**场景2：特定用户走 v2**
```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml
```

这个配置的逻辑是：
- 如果请求头 `end-user=jason`，走 v2
- 其他用户走 v1

验证：
1. 不登录访问：只看到文字评价（v1）
2. 用 jason 登录：看到黑色星星（v2）
3. 用其他用户登录：只看到文字评价（v1）

这就是基于用户的路由，可以用于 A/B 测试、内测等场景。

---

## 实现灰度发布

灰度发布是 Istio 最常用的功能之一。假设我们要把 reviews 从 v1 升级到 v2，但不想一次性全量发布，而是先让 10% 的用户试用。

创建灰度发布配置：
```yaml
# virtual-service-reviews-90-10.yaml
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
      weight: 90    # 90% 流量走 v1
    - destination:
        host: reviews
        subset: v2
      weight: 10    # 10% 流量走 v2
```

```bash
kubectl apply -f virtual-service-reviews-90-10.yaml
```

刷新页面 10 次，大约 9 次看到文字评价（v1），1 次看到黑色星星（v2）。

**逐步增加 v2 流量**：
```
第一周：90% v1 / 10% v2  → 观察指标
第二周：70% v1 / 30% v2  → 继续观察
第三周：50% v1 / 50% v2  → 没问题
第四周：0% v1 / 100% v2  → 全量发布
```

这就是灰度发布的精髓：小步快跑，逐步验证，随时可以回滚。传统方式需要改代码、改配置、重新部署，而 Istio 只需要改一个配置文件，秒级生效。

---

## 核心概念回顾

通过 BookInfo 示例，你接触到了 Istio 的几个核心概念：

| 概念 | 作用 | 类比 |
|------|------|------|
| Gateway | 定义入口 | 书店的大门 |
| VirtualService | 定义路由规则 | 交通指挥 |
| DestinationRule | 定义目的地策略 | 路标 |
| Subset | 服务的子集/版本 | 不同的车道 |
| Weight | 流量权重 | 分流比例 |

这些概念的关系：
```
外部流量 → Gateway → VirtualService → DestinationRule → Subset → Pod
```

---

## 清理资源

实验完成后，清理资源：
```bash
# 删除 BookInfo 应用
kubectl delete -f samples/bookinfo/platform/kube/bookinfo.yaml

# 删除 Gateway 和路由规则
kubectl delete -f samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl delete -f samples/bookinfo/networking/destination-rule-all.yaml
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

---

## 核心要点总结

1. **BookInfo 架构**：4 个服务，reviews 有 3 个版本
2. **部署应用**：`kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml`
3. **配置 Gateway**：让外部能访问应用
4. **DestinationRule**：定义服务的子集（版本）
5. **VirtualService**：定义流量路由规则
6. **灰度发布**：通过 weight 权重控制流量分配

记住：**不用改代码，只改配置，这就是 Istio 的魔力！**

---

## 下一步

现在你已经体验了 Istio 的基本功能，下一步深入学习流量管理：

- 如何实现更复杂的流量控制？
- 如何实现故障注入测试？
- 如何实现超时和重试？
- 如何实现熔断保护？

下一篇《流量管理 - 指挥交通的艺术》将为你详细讲解！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-14
- 基于 Istio 版本：1.20+

---

**上一篇**：[Istio 安装指南 - 让魔法生效](02-istio-installation.md)  
**下一篇**：[流量管理 - 指挥交通的艺术](04-traffic-management.md)
