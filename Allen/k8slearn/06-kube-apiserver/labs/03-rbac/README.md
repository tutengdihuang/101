# Lab 03 - RBAC 授权（Role/ClusterRole + Binding）

## 目标

- 理解 RBAC 的四个核心对象：Role / ClusterRole / RoleBinding / ClusterRoleBinding
- 用最小样例把 `cluster-admin` 绑定给某个 user（仅用于理解，不建议生产使用）

## 对应来源

- 本仓库：`module6/rbac/cluster-admin-to-mfanjie.yaml`
- 训练营：模块六（API Server）-> 鉴权（RBAC vs ABAC、Role/Binding）

## 实验步骤

### 1. 应用 RoleBinding（把 cluster-admin 绑定给用户）

```sh
kubectl apply -f cluster-admin-to-user.yaml
```

### 2. 验证

```sh
kubectl auth can-i '*' '*' --as mfanjie -n default
kubectl get pods -n default --as mfanjie
```

## 说明（生产注意）

- `cluster-admin` 权限非常大。
- 实际生产建议：
  - 优先创建自定义 `Role/ClusterRole`
  - 最小化 verbs/resources
  - 用 GitOps/代码化方式管理权限（避免临时 edit 导致权限失控）

## 清理

```sh
kubectl delete -f cluster-admin-to-user.yaml
```

## 验证结果

### 验证脚本执行记录

使用 `verify.sh` 脚本对 RBAC 授权进行验证：

```bash
./verify.sh
```

#### 验证步骤

1. **创建测试用户 Role**
   - 创建名为 `pod-reader` 的 Role
   - 设置允许的 verbs: get, list, watch
   - 设置允许的 resources: pods
   - 验证 Role 创建成功

2. **创建 RoleBinding**
   - 创建 RoleBinding 将 Role 绑定到测试用户
   - 设置 subjects 为用户 `testuser`
   - 验证 RoleBinding 创建成功

3. **验证用户权限**
   - 使用 `kubectl auth can-i` 验证用户权限
   - 测试有权限的操作（get, list, watch pods）
   - 测试无权限的操作（create, delete, update pods）
   - 测试无权限的资源（services, deployments）

4. **测试实际资源访问**
   - 使用 `--as testuser` 参数模拟用户访问
   - 验证有权限的操作成功
   - 验证无权限的操作返回 Forbidden 错误

5. **验证 ClusterRole 和 ClusterRoleBinding**
   - 创建 ClusterRole 定义集群级别权限
   - 创建 ClusterRoleBinding 绑定到用户
   - 验证跨 namespace 权限

6. **清理测试资源**
   - 删除 Role 和 RoleBinding
   - 删除 ClusterRole 和 ClusterRoleBinding
   - 验证清理完成

#### 预期结果

- Role 和 RoleBinding 创建成功
- 有权限的操作（get, list, watch pods）返回 yes
- 无权限的操作（create, delete, update pods）返回 no
- 无权限的资源（services, deployments）返回 no
- 实际资源访问时，有权限的操作成功执行
- 实际资源访问时，无权限的操作返回 Forbidden 错误
- ClusterRole 和 ClusterRoleBinding 提供集群级别权限

#### 验证输出示例

```
==========================================
Lab 03 - RBAC 授权验证
==========================================

1. 检查现有 Role 和 ClusterRole
------------------------------------------
NAME                                                      CREATED AT
role.rbac.authorization.k8s.io/pod-reader                   2026-01-24T13:19:21Z
role.rbac.authorization.k8s.io/developer                   2026-01-24T13:32:51Z
role.rbac.authorization.k8s.io/admin                       2025-12-23T12:17:21Z
role.rbac.authorization.k8s.io/argocd-manager               2025-12-23T12:17:21Z
...
clusterrole.rbac.authorization.k8s.io/cluster-admin         2025-12-23T11:18:40Z
clusterrole.rbac.authorization.k8s.io/edit                  2025-12-23T11:18:40Z
...

2. 检查现有 RoleBinding 和 ClusterRoleBinding
------------------------------------------
NAME                                              ROLE              AGE
rolebinding.rbac.authorization.k8s.io/read-pods   Role/pod-reader   13m

clusterrolebinding.rbac.authorization.k8s.io/cluster-admin   ClusterRole/cluster-admin   31d
...

3. 创建测试用户 Role
------------------------------------------
role.rbac.authorization.k8s.io/pod-reader unchanged

4. 创建 RoleBinding
------------------------------------------
rolebinding.rbac.authorization.k8s.io/read-pods unchanged

5. 验证用户权限 (使用 --as 参数)
------------------------------------------
测试用户 testuser 是否可以 list pods:
yes

测试用户 testuser 是否可以 create pods:
no

==========================================
验证完成
==========================================

RBAC 关键点：
- Role 定义 namespace 级别的权限
- ClusterRole 定义集群级别的权限
- RoleBinding 将 Role 绑定到用户/组/服务账户
- ClusterRoleBinding 将 ClusterRole 绑定到用户/组/服务账户
- 权限由 verbs、resources、apiGroups 组合定义
- 最小权限原则：只授予必要的权限
```

**注意**：验证脚本执行到权限测试步骤后退出，未完成所有验证步骤。Role 和 RoleBinding 已存在（unchanged），说明之前已经创建过。权限验证显示 testuser 用户可以 list pods，但不能 create pods，符合预期。

### 关键验证点

**当前验证结果**：
- [x] Role 已存在（pod-reader）
- [x] RoleBinding 已存在（read-pods）
- [x] 有权限的操作（list pods）通过 `kubectl auth can-i` 验证
- [x] 无权限的操作（create pods）通过 `kubectl auth can-i` 验证
- [ ] 验证脚本未完成所有步骤

**完整验证需要**：
- [x] Role 创建成功，定义正确的 verbs 和 resources
- [x] RoleBinding 创建成功，正确绑定到用户
- [x] 有权限的操作通过 `kubectl auth can-i` 验证
- [x] 无权限的操作通过 `kubectl auth can-i` 验证
- [ ] 实际资源访问时，有权限的操作成功执行
- [ ] 实际资源访问时，无权限的操作返回 Forbidden 错误
- [ ] ClusterRole 和 ClusterRoleBinding 创建成功
- [ ] 集群级别权限正确生效
- [ ] 测试资源清理完成

