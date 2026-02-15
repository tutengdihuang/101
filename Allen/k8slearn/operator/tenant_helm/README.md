# tenant-operator Helm Chart

通过 Helm 部署 tenant-operator，实现多租户管理。

## 快速开始

### 安装 Operator

```bash
# 使用默认配置安装
helm install tenant-operator ./tenant_helm

# 自定义配置安装
helm install tenant-operator ./tenant_helm \
  --set image.tag=v1.0.0 \
  --set createExampleTenant=true \
  --set tenant.spec.namespace=my-tenant
```

### 使用 values 文件

```bash
# 创建 my-values.yaml
cat > my-values.yaml << EOF
image:
  tag: v1.0.0
createExampleTenant: true
tenant:
  name: my-tenant
  spec:
    namespace: my-tenant-ns
    adminUser: tenant-admin
    objectCounts:
      configMaps: "20"
      secrets: "20"
      services: "10"
    podQuota:
      pods: "50"
EOF

# 使用 values 文件安装
helm install tenant-operator ./tenant_helm -f my-values.yaml
```

## 配置说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `image.repository` | Operator 镜像仓库 | `crpi-j9gshcbjtb1i6c7h.../tenant-operator` |
| `image.tag` | Operator 镜像标签 | `latest` |
| `image.pullPolicy` | 镜像拉取策略 | `Always` |
| `installCRD` | 是否安装 CRD | `true` |
| `createExampleTenant` | 是否创建示例 Tenant | `false` |
| `tenant.spec.namespace` | 租户命名空间 | `demo` |
| `tenant.spec.adminUser` | 租户管理员 | `admin` |
| `tenant.spec.objectCounts` | 资源数量限制 | `configMaps:10, secrets:10, services:5` |
| `tenant.spec.podQuota.pods` | Pod 配额 | `10` |

## 升级

```bash
helm upgrade tenant-operator ./tenant_helm --set image.tag=v2.0.0
```

## 卸载

```bash
helm uninstall tenant-operator
```

## 手动创建 Tenant

```yaml
apiVersion: tenant.cncamp.io/v1alpha1
kind: Tenant
metadata:
  name: my-tenant
spec:
  namespace: my-tenant-ns
  adminUser: tenant-admin
  objectCounts:
    configMaps: "20"
    secrets: "20"
    services: "10"
  podQuota:
    pods: "50"
```

```bash
kubectl apply -f my-tenant.yaml
```

## Tenant CRD 说明

Tenant Operator 会自动为每个租户创建：
- Namespace
- ResourceQuota（资源配额）
- RoleBinding（管理员权限）

## 文件结构

```
tenant_helm/
├── Chart.yaml              # Chart 元数据
├── values.yaml             # 可配置参数
├── README.md               # 使用说明
└── templates/
    ├── _helpers.tpl        # 模板助手函数
    ├── crd.yaml            # CRD 定义
    ├── namespace.yaml      # Operator 命名空间
    ├── serviceaccount.yaml # ServiceAccount
    ├── clusterrole.yaml    # ClusterRole
    ├── clusterrolebinding.yaml # ClusterRoleBinding
    ├── deployment.yaml     # Operator Deployment
    └── tenant-cr.yaml      # 示例 Tenant (可选)
```
