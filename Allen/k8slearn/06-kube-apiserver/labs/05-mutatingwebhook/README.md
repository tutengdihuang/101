# Lab 05 - Mutating Webhook（动态修改 API 对象）

## 目标

- 部署一个 Mutating Webhook 服务
- 在集群中创建 MutatingWebhookConfiguration
- 验证创建 Pod 时，webhook 自动注入 sidecar 容器

## 对应来源

- 本仓库：`module6/mutatingwebhook/readme.MD`
- 示例仓库：[cncamp/admission-controller-webhook-demo](https://github.com/cncamp/admission-controller-webhook-demo)
- 训练营：模块六（API Server）-> 准入控制（MutatingWebhook）

## 前置条件

- 一个可以部署 Deployment 的集群（minikube/kind/kubeadm 均可）
- `kubectl` 已配置管理员权限
- `git` 和 `make` 工具

## 实验步骤

### 1. 克隆示例仓库

```sh
git clone https://github.com/cncamp/admission-controller-webhook-demo.git
cd admission-controller-webhook-demo
```

### 2. 部署 webhook 服务

```sh
./deploy.sh
```

这会创建：
- 一个 Deployment + Service（`webhook-server`）
- 一个 MutatingWebhookConfiguration（`demo-webhook`）
- 必要的 RBAC 权限

### 3. 验证 webhook 服务状态

```sh
kubectl get deployment -n webhook-demo
kubectl get pods -n webhook-demo
kubectl get mutatingwebhookconfigurations demo-webhook
```

### 4. 测试 webhook 效果

创建一个 Pod：

```sh
kubectl create -f examples/pod-with-defaults.yaml
```

检查 Pod 是否被注入了 sidecar：

```sh
kubectl get pod pod-with-defaults -o jsonpath='{.spec.containers[*].name}'
# 输出示例: nginx sidecar-1 sidecar-2
```

### 5. 查看 webhook 日志

```sh
kubectl logs -n webhook-demo -l app=webhook-server -f
```

## 原理解析

1. **MutatingWebhookConfiguration** 定义了：
   - 哪些资源（`rules`）需要发送到 webhook
   - webhook 服务的地址（`clientConfig.service`）
   - 失败策略（`failurePolicy`）

2. webhook 服务接收 `AdmissionReview` 请求，返回 `AdmissionResponse` 包含 patch 操作：
   - 添加 sidecar 容器
   - 添加 init 容器
   - 修改环境变量等

## 清理

```sh
kubectl delete -f examples/pod-with-defaults.yaml
kubectl delete -f deploy/
```

## 进阶：自定义 webhook

1. 修改 `main.go` 中的 `mutation` 函数
2. 重新构建并推送镜像
3. 更新 Deployment 镜像版本
4. 重新部署

## 常见问题

- **证书问题**：如果 webhook 服务使用自签名证书，需要确保 `caBundle` 正确配置
- **超时**：默认超时 10s，如果 webhook 响应慢可能导致请求失败（可调整 `timeoutSeconds`）
- **循环调用**：避免 webhook 修改自己的资源，导致死循环

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 Mutating Webhook 进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **检查 MutatingWebhookConfiguration**
   - 验证 MutatingWebhookConfiguration 是否存在
   - 检查 webhook 配置是否正确
   - 验证规则配置（rules）

2. **检查 webhook 服务状态**
   - 验证 webhook Deployment 是否运行
   - 检查 webhook Pod 状态
   - 验证 webhook Service 是否存在

3. **创建测试 Pod**
   - 创建一个简单的测试 Pod
   - 验证 Pod 创建成功

4. **验证 sidecar 注入**
   - 检查 Pod 的容器列表
   - 验证 sidecar 容器是否被注入
   - 验证 sidecar 容器的配置

5. **测试 webhook 拦截**
   - 创建另一个测试 Pod
   - 验证 webhook 是否正确拦截请求
   - 检查 webhook 日志

6. **清理测试资源**
   - 删除测试 Pod
   - 验证清理完成

#### 预期结果

- MutatingWebhookConfiguration 配置正确
- webhook 服务正常运行
- 测试 Pod 创建成功
- sidecar 容器被正确注入
- webhook 正确拦截和修改 Pod 创建请求
- webhook 日志显示正确的处理记录

#### 验证输出示例

```
==========================================
Lab 05 - Mutating Webhook 验证
==========================================

1. 检查 MutatingWebhookConfiguration
------------------------------------------
NAME                     WEBHOOKS   AGE
istio-sidecar-injector   4          12d

2. 检查 webhook 服务
------------------------------------------
NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-egressgateway    1/1     1            1           12d
deployment.apps/istio-ingressgateway   1/1     1            1           12d
deployment.apps/istiod                 1/1     1            1           12d

NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                      AGE
service/istio-egressgateway    ClusterIP      10.102.75.26    <none>        80/TCP,443/TCP                                                               12d
service/istio-ingressgateway   LoadBalancer   10.99.142.41    <pending>     15021:30957/TCP,80:31868/TCP,443:31426/TCP,31400:31562/TCP,15443:30119/TCP   12d
service/istiod                 ClusterIP      10.111.84.175   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP                                        12d

NAME                                        READY   STATUS    RESTARTS   AGE
pod/istio-egressgateway-7b686cb64d-8lzw5    1/1     Running   0          12d
pod/istio-ingressgateway-77bfdf67f4-k7cnz   1/1     Running   0          12d
pod/istiod-596db4b9bf-4mnnz                 1/1     Running   0          12d

3. 检查 webhook 服务日志
------------------------------------------
Webhook 服务日志 (最近 10 行):
No resources found in istio-system namespace.

4. 创建测试 Pod
------------------------------------------
pod/test-pod created

5. 等待 Pod 创建
------------------------------------------
error: timed out waiting for condition on pods/test-pod

6. 检查 Pod 容器列表
------------------------------------------
Pod 容器名称:
nginx

Pod 详细信息:
  containers:
  - image: nginx:1.19
    imagePullPolicy: IfNotPresent
    name: nginx
    ports:
    - containerPort: 80
      protocol: TCP
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:

7. 检查是否注入了 sidecar
------------------------------------------
容器数量: ${CONTAINER_COUNT}
✗ Webhook 未注入 sidecar 容器

8. 查看 webhook 服务器日志
------------------------------------------
Webhook 服务器最近的日志:
No resources found in istio-system namespace.

9. 清理测试 Pod
------------------------------------------
pod "test-pod" deleted

==========================================
验证完成
==========================================

注意：
- 如果 webhook 服务未部署，需要先运行 deploy.sh
- 如果没有看到 sidecar 注入，检查 webhook 配置和日志
- 可以通过修改 webhook 代码来自定义注入逻辑

Mutating Webhook 关键点：
- MutatingWebhookConfiguration 定义 webhook 规则
- webhook 服务接收 AdmissionReview 请求
- webhook 返回 AdmissionResponse 包含 patch 操作
- 可以动态修改 API 对象（添加容器、修改环境变量等）
- 属于准入控制阶段，在对象持久化前执行
```

**注意**：当前集群存在 Istio 的 MutatingWebhookConfiguration（istio-sidecar-injector），但测试 Pod 未被注入 sidecar 容器。可能原因：
1. 测试 Pod 未在正确的 namespace 中（Istio sidecar 注入通常需要 namespace 启用 Istio）
2. Pod 的标签或注解不符合 Istio sidecar 注入条件
3. webhook 配置的规则未匹配到测试 Pod
4. 需要为 namespace 添加 `istio-injection=enabled` 标签

### 关键验证点

**当前验证结果**：
- [x] MutatingWebhookConfiguration 存在（istio-sidecar-injector）
- [x] webhook 服务正常运行（Istio 相关服务）
- [x] 测试 Pod 创建成功
- [ ] sidecar 容器未被注入
- [ ] webhook 日志无法获取
- [ ] 测试资源清理完成

**完整验证需要**：
- [x] MutatingWebhookConfiguration 配置正确
- [x] webhook 服务正常运行
- [x] 测试 Pod 创建成功
- [ ] sidecar 容器被正确注入
- [ ] webhook 正确拦截和修改 Pod 创建请求
- [ ] webhook 日志显示正确的处理记录
- [x] 测试资源清理完成

