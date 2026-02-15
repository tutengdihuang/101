# k8s-test-operator Helm Chart

通过 Helm 部署 k8s-test-operator，自动管理微服务应用部署。

## 快速开始

### 安装 Operator

```bash
# 使用默认配置安装
helm install k8s-test-operator ./operator_helm

# 自定义配置安装
helm install k8s-test-operator ./operator_helm \
  --set image.tag=v1.0.0 \
  --set createExampleCR=true \
  --set k8stest.spec.replicas=3
```

### 使用 values 文件

```bash
# 创建 my-values.yaml
cat > my-values.yaml << EOF
image:
  tag: v1.0.0
createExampleCR: true
k8stest:
  spec:
    replicas: 3
    imageTag: v1.0.0
EOF

# 使用 values 文件安装
helm install k8s-test-operator ./operator_helm -f my-values.yaml
```

## 配置说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `image.repository` | Operator 镜像仓库 | `crpi-j9gshcbjtb1i6c7h.../k8s-test-operator` |
| `image.tag` | Operator 镜像标签 | `latest` |
| `image.pullPolicy` | 镜像拉取策略 | `Always` |
| `installCRD` | 是否安装 CRD | `true` |
| `createExampleCR` | 是否创建示例 CR | `false` |
| `k8stest.spec.replicas` | 示例 CR 副本数 | `2` |
| `k8stest.spec.imageRegistry` | 镜像仓库地址 | `crpi-j9gshcbjtb1i6c7h...` |
| `k8stest.spec.imageTag` | 应用镜像标签 | `latest` |

## 升级

```bash
helm upgrade k8s-test-operator ./operator_helm --set image.tag=v2.0.0
```

## 卸载

```bash
helm uninstall k8s-test-operator
```

## 手动创建 CR

```yaml
apiVersion: apps.cncamp.io/v1alpha1
kind: K8sTest
metadata:
  name: my-app
  namespace: service-test
spec:
  namespace: service-test
  imageRegistry: my-registry
  imageTag: v1.0.0
  replicas: 3
```

```bash
kubectl apply -f my-app.yaml
```

## 文件结构

```
operator_helm/
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
    └── k8stest-cr.yaml     # 示例 CR (可选)
```
