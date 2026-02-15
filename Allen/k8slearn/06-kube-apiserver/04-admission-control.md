# 04 - 准入控制（Admission Control）：最后的把关者

> 目标：理解准入控制如何作为“最后一道防线”，拦截或修改 API 请求，并实现自定义逻辑。

## 训练营要点（提炼总结）

训练营把准入控制定位为“写请求的看门人”，核心职责是：
- **拦截**：可以拦截所有写请求（create/update/delete）
- **修改**：可以修改请求内容（Mutating）
- **验证**：可以拒绝请求（Validating）
- **默认值**：可以自动填充默认值
- **策略**：执行自定义业务规则（如资源配额、镜像拉取策略）

## 准入控制的工作时机

```
认证 → 鉴权 → 准入控制 → 持久化到 etcd
```

关键点：
- 只在写操作时触发（读操作不经过准入）
- 在鉴权（RBAC）之后，确保只有有权限的请求才会进入准入
- 可以配置多个准入控制器，按顺序执行

## 内置准入控制器

训练营提到几个关键的内置控制器：

### 1. ResourceQuota
- 限制 namespace 内的资源使用量
- 示例：限制 default 命名空间最多 10 个 Pod

### 2. LimitRanger
- 为容器设置默认资源请求/限制
- 示例：如果 Pod 没设置 requests/limits，自动添加

### 3. PodSecurityPolicy（已废弃，由 Pod Security Admission 替代）
- 控制 Pod 的安全相关设置
- 示例：禁止 privileged 容器

### 4. NamespaceLifecycle
- 防止在 terminating 的 namespace 中创建资源
- 确保 namespace 存在才允许创建资源

## 动态准入控制：Webhook

训练营重点介绍了 MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook：

### MutatingAdmissionWebhook
- 可以修改请求对象
- 常见用途：
  - 注入 sidecar 容器（如 Istio）
  - 自动添加标签/注解
  - 设置默认值

### ValidatingAdmissionWebhook
- 只能验证请求，不能修改
- 常见用途：
  - 验证资源字段合法性
  - 执行业务规则（如“生产环境必须指定 team 标签”）
  - 防止配置错误（如无效的镜像标签）

## 准入控制实战

### 1. 启用准入控制器

在 apiserver 启动参数中配置：

```yaml
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ResourceQuota
--disable-admission-plugins=AlwaysDeny  # 显式禁用不需要的插件
```

### 2. 验证准入控制

```sh
# 查看当前启用的准入控制器
kubectl -n kube-system get pods -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}'
```

### 3. 实验：ResourceQuota

```yaml
# quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: default
spec:
  hard:
    pods: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
```

应用配置：

```sh
kubectl apply -f quota.yaml
```

测试：

```sh
# 创建超过限制的 Pod
kubectl run nginx --image=nginx --replicas=11

# 查看事件
kubectl get events --field-selector reason=FailedCreate
```

## 排障：准入控制相关错误

### 1. 请求被拒绝，但没有明显原因

```sh
# 查看 apiserver 日志
kubectl -n kube-system logs -l component=kube-apiserver | grep -i "admission.*deny"
```

### 2. Webhook 超时

```
admission webhook "example.com" failed to respond within 30s
```

解决方案：
1. 检查 webhook 服务是否可达
2. 增加超时时间（如果可能）
3. 优化 webhook 性能

### 3. 循环调用

如果 webhook 修改了资源，可能会导致循环调用。

解决方案：
- 在 webhook 中添加标签/注解，避免重复处理
- 确保 webhook 不会处理自己的更新

## 实践

- [Lab 05 Mutating Webhook](labs/05-mutatingwebhook/README.md)
- [Lab 06 ResourceQuota](labs/06-resourcequota/README.md)

## 自测问题

1. 为什么准入控制在鉴权之后执行？
2. 如果一个请求被多个 Mutating Webhook 处理，顺序如何确定？
3. 如何防止 Mutating Webhook 导致无限循环？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**上一篇**：[03 RBAC 鉴权](03-authorization-rbac.md)  
**下一篇**：[05 限流与 API 优先级](05-rate-limit-and-apf.md)
