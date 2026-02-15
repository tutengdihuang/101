# Lab 06 - ResourceQuota（限制 namespace 资源/对象）

## 目标

- 在指定 namespace 应用 `ResourceQuota`
- 验证配额生效：当对象数量超过上限时，创建请求被拒绝

## 对应来源

- 本仓库：`module6/quota/quota.yaml`
- 训练营：模块六（API Server）-> 准入控制插件（ResourceQuota）

## 前置条件

- 可访问集群的 `kubectl`
- 具有在目标 namespace 创建配额对象的权限

## 实验内容

本实验的样例配额：限制 `default` namespace 内 `configmaps` 数量最多为 1。

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: default
spec:
  hard:
    configmaps: "1"
```

## 实验步骤

### 1. 应用配额

```sh
kubectl apply -f quota.yaml
kubectl get resourcequota -n default
kubectl describe resourcequota object-counts -n default
```

### 2. 创建第一个 ConfigMap（应成功）

```sh
kubectl create configmap cm-1 -n default --from-literal=k=v
```

### 3. 创建第二个 ConfigMap（应失败）

```sh
kubectl create configmap cm-2 -n default --from-literal=k=v
```

预期错误类似：

- exceeded quota: object-counts

### 4. 清理

```sh
kubectl delete configmap cm-1 -n default
kubectl delete -f quota.yaml
```

## 思考题

- ResourceQuota 为什么属于"准入"范畴？它是在什么时候拦截请求的？
- 如果你对一个 namespace 想做"对象数 + CPU/Memory + PVC"综合限制，你会如何规划 quota？

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 ResourceQuota 进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **检查现有 ResourceQuota**
   - 查看当前 namespace 中的 ResourceQuota
   - 检查配额使用情况

2. **检查现有 ConfigMap 数量**
   - 统计当前 namespace 中的 ConfigMap 数量
   - 为测试做准备

3. **清理现有 ConfigMap**
   - 删除所有 ConfigMap（为测试做准备）
   - 删除现有 ResourceQuota

4. **创建测试 ResourceQuota**
   - 创建限制对象数量的 ResourceQuota
   - 设置 ConfigMap 限制为 2
   - 设置 Pod 限制为 2
   - 设置 Service 限制为 1

5. **查看 ResourceQuota 状态**
   - 验证 ResourceQuota 创建成功
   - 检查配额限制和使用情况

6. **创建第一个 ConfigMap**
   - 创建第一个 ConfigMap（应该成功）
   - 验证配额使用情况更新

7. **创建第二个 ConfigMap**
   - 创建第二个 ConfigMap（应该失败）
   - 验证配额限制生效

8. **测试 Pod 配额限制**
   - 创建第一个 Pod（应该成功）
   - 创建第二个 Pod（应该成功）
   - 创建第三个 Pod（应该失败）

9. **测试 CPU/Memory 配额**
   - 创建 CPU/Memory 配额
   - 验证计算资源限制

10. **清理测试资源**
    - 删除测试 ConfigMap 和 Pod
    - 删除 ResourceQuota
    - 验证清理完成

#### 预期结果

- ResourceQuota 创建成功
- 第一个 ConfigMap 创建成功
- 第二个 ConfigMap 创建失败（超出配额）
- 第一个和第二个 Pod 创建成功
- 第三个 Pod 创建失败（超出配额）
- CPU/Memory 配额创建成功
- 测试资源清理完成

#### 验证输出示例

```
==========================================
Lab 06 - ResourceQuota 验证
==========================================

1. 检查现有 ResourceQuota
------------------------------------------
NAME            AGE   REQUEST                                     LIMIT
object-counts   63s   configmaps: 1/1, pods: 0/2, services: 1/1   

2. 检查现有 ConfigMap 数量
------------------------------------------
2

2.1 清理现有 ConfigMap (为测试做准备)
------------------------------------------
configmap "kube-root-ca.crt" deleted
resourcequota "object-counts" deleted

2.2 检查清理后的 ConfigMap 数量
------------------------------------------
2

3. 创建测试 ResourceQuota
------------------------------------------
resourcequota/object-counts created

4. 查看 ResourceQuota 状态
------------------------------------------
Name:       object-counts
Namespace:  default
Resource    Used  Hard
--------    ----  ----
configmaps  1     2
pods        0     2
services    1     1

5. 创建第一个 ConfigMap (应该成功)
------------------------------------------
configmap/cm-test-1 created

6. 查看 ResourceQuota 使用情况
------------------------------------------
  used:
    configmaps: "2"
    pods: "0"
    services: "1"

7. 创建第二个 ConfigMap (应该失败)
------------------------------------------
Error from server (Forbidden): error when creating "STDIN": configmaps "cm-test-2" is forbidden: exceeded quota: object-counts, requested: configmaps=1, used: configmaps=2, limited: configmaps=2
第二个 ConfigMap 创建失败 (符合预期)

8. 测试 Pod 配额限制
------------------------------------------
创建第一个 Pod (应该成功):
pod/test-pod-1 created

创建第二个 Pod (应该成功):
pod/test-pod-2 created

创建第三个 Pod (应该失败):
Error from server (Forbidden): pods "test-pod-3" is forbidden: exceeded quota: object-counts, requested: pods=1, used: pods=2, limited: pods=2
第三个 Pod 创建失败 (符合预期)

9. 查看 ResourceQuota 最终状态
------------------------------------------
Name:       object-counts
Namespace:  default
Resource    Used  Hard
--------    ----  ----
configmaps  2     2
pods        2     2
services    1     1

10. 测试 CPU/Memory 配额
------------------------------------------
创建 CPU/Memory 配额:
resourcequota/compute-resources created

查看 CPU/Memory 配额状态:
Name:            compute-resources
Namespace:       default
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     2
limits.memory    0     2Gi
requests.cpu     0     1
requests.memory  0     1Gi

11. 清理测试资源
------------------------------------------
configmap "cm-test-1" deleted
pod "test-pod-1" deleted
pod "test-pod-2" deleted
resourcequota "object-counts" deleted
resourcequota "compute-resources" deleted
清理完成

==========================================
验证完成
==========================================

ResourceQuota 关键点：
- 限制 namespace 内的资源数量
- 限制 CPU/Memory 等计算资源
- 属于准入控制插件，在对象创建时检查
- 可以结合 LimitRange 使用
- 支持多种资源类型：pods, services, configmaps, persistentvolumeclaims 等
- 支持计算资源：requests.cpu, requests.memory, limits.cpu, limits.memory
```

**注意**：验证成功完成。ResourceQuota 正确限制了 namespace 内的资源数量，超出配额的创建请求被正确拒绝。

### 关键验证点

**当前验证结果**：
- [x] ResourceQuota 创建成功
- [x] 第一个 ConfigMap 创建成功
- [x] 第二个 ConfigMap 创建失败（超出配额）
- [x] 第一个和第二个 Pod 创建成功
- [x] 第三个 Pod 创建失败（超出配额）
- [x] CPU/Memory 配额创建成功
- [x] 配额限制正确生效
- [x] 测试资源清理完成

**完整验证需要**：
- [x] ResourceQuota 创建成功
- [x] 第一个 ConfigMap 创建成功
- [x] 第二个 ConfigMap 创建失败（超出配额）
- [x] 第一个和第二个 Pod 创建成功
- [x] 第三个 Pod 创建失败（超出配额）
- [x] CPU/Memory 配额创建成功
- [x] 配额限制正确生效
- [x] 测试资源清理完成

