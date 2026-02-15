# k8s-test-operator 项目创建与编写详解

## 一、项目概述

这是一个 **微服务应用部署 Operator**，通过创建一个 `K8sTest` CR，自动部署一套完整的微服务架构应用。

---

## 二、项目创建步骤

### 1. 安装 Kubebuilder

```bash
# macOS
brew install kubebuilder

# 或下载二进制
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
chmod +x kubebuilder && mv kubebuilder /usr/local/bin/
```

### 2. 初始化项目

```bash
# 创建项目目录
mkdir k8s-test-operator && cd k8s-test-operator

# 初始化项目 (domain 是 CRD 的 API 域名后缀)
kubebuilder init --domain cncamp.io --repo github.com/cncamp/101/Allen/k8slearn/operator/k8s-test-operator
```

**生成的目录结构：**

```
k8s-test-operator/
├── cmd/main.go              # 程序入口
├── api/                     # CRD 定义 (稍后创建)
├── internal/controller/     # Controller 逻辑 (稍后创建)
├── config/                  # Kubernetes 部署配置
│   ├── crd/                 # CRD YAML
│   ├── rbac/                # RBAC 权限
│   ├── manager/             # Deployment 配置
│   └── samples/             # 示例 CR
├── PROJECT                  # 项目元数据
├── Makefile                 # 构建脚本
└── go.mod                   # Go 依赖
```

### 3. 创建 API (CRD + Controller)

```bash
# 创建 K8sTest CRD，group=apps，version=v1alpha1
kubebuilder create api --group apps --version v1alpha1 --kind K8sTest --namespaced --resource --controller
```

**生成的文件：**

- `api/v1alpha1/k8stest_types.go` - CRD 定义
- `internal/controller/k8stest_controller.go` - Controller 逻辑

---

## 三、编写 CRD 定义

编辑 `api/v1alpha1/k8stest_types.go`：

```go
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// K8sTestSpec 定义期望状态
type K8sTestSpec struct {
    // +optional
    Foo *string `json:"foo,omitempty"`

    // 目标命名空间
    Namespace     string `json:"namespace,omitempty"`
    // 镜像仓库地址
    ImageRegistry string `json:"imageRegistry,omitempty"`
    // 镜像标签
    ImageTag      string `json:"imageTag,omitempty"`
    // 副本数
    Replicas      *int32 `json:"replicas,omitempty"`
    // 镜像拉取密钥
    PullSecret    string `json:"pullSecret,omitempty"`
}

// K8sTestStatus 定义观测状态
type K8sTestStatus struct {
    // 条件状态
    // +optional
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
type K8sTest struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitzero"`
    Spec   K8sTestSpec   `json:"spec"`
    Status K8sTestStatus `json:"status,omitzero"`
}

// +kubebuilder:object:root=true
type K8sTestList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitzero"`
    Items           []K8sTest `json:"items"`
}
```

### CRD 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `spec.namespace` | string | 目标命名空间 |
| `spec.imageRegistry` | string | 镜像仓库地址 |
| `spec.imageTag` | string | 镜像标签 |
| `spec.replicas` | *int32 | 副本数 |
| `spec.pullSecret` | string | 镜像拉取密钥 |
| `status.conditions` | []Condition | 资源状态条件 |

---

## 四、编写 Controller 逻辑

编辑 `internal/controller/k8stest_controller.go`：

### 4.1 Reconcile 函数结构

```go
func (r *K8sTestReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := logf.FromContext(ctx)

    // 1. 获取 CR 实例
    var k8stest appsv1alpha1.K8sTest
    if err := r.Get(ctx, req.NamespacedName, &k8stest); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 2. 设置默认值
    targetNS := k8stest.Spec.Namespace
    if targetNS == "" {
        targetNS = req.Namespace
    }

    imageRegistry := k8stest.Spec.ImageRegistry
    if imageRegistry == "" {
        imageRegistry = "crpi-j9gshcbjtb1i6c7h.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang"
    }

    // 3. 确保各种资源
    if err := r.ensureEtcdConfigMap(ctx, &k8stest, targetNS); err != nil {
        return ctrl.Result{}, err
    }
    if err := r.ensureEtcd(ctx, &k8stest, targetNS, pullSecret); err != nil {
        return ctrl.Result{}, err
    }
    if err := r.ensureRPCService(ctx, &k8stest, targetNS, "user-service", ...); err != nil {
        return ctrl.Result{}, err
    }
    // ... 更多资源

    return ctrl.Result{}, nil
}
```

### 4.2 使用 CreateOrUpdate 模式

```go
func (r *K8sTestReconciler) ensureEtcd(ctx context.Context, owner *appsv1alpha1.K8sTest, ns string) error {
    dep := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "etcd",
            Namespace: ns,
        },
    }

    // CreateOrUpdate: 如果不存在则创建，存在则更新
    _, err := controllerutil.CreateOrUpdate(ctx, r.Client, dep, func() error {
        // 设置 OwnerReference，当 CR 删除时自动清理资源
        if err := controllerutil.SetControllerReference(owner, dep, r.Scheme); err != nil {
            return err
        }

        // 配置 Deployment
        labels := map[string]string{"app": "etcd"}
        dep.Labels = labels
        dep.Spec.Replicas = int32Ptr(1)
        dep.Spec.Selector = &metav1.LabelSelector{MatchLabels: labels}
        dep.Spec.Template.ObjectMeta.Labels = labels
        dep.Spec.Template.Spec.Containers = []corev1.Container{
            {
                Name:  "etcd",
                Image: "registry.aliyuncs.com/google_containers/etcd:3.5.9-0",
                Command: []string{
                    "etcd",
                    "--listen-client-urls=http://0.0.0.0:2379",
                    "--advertise-client-urls=http://0.0.0.0:2379",
                },
                Ports: []corev1.ContainerPort{{ContainerPort: 2379}},
            },
        }
        return nil
    })
    return err
}
```

### 4.3 RBAC 权限标记

在 Controller 文件顶部添加 RBAC 权限标记：

```go
// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=events.k8s.io,resources=events,verbs=create;patch
```

---

## 五、Reconcile 创建的资源

当用户创建一个 `K8sTest` CR 时，Operator 会自动创建以下资源：

| 资源类型 | 名称 | 说明 |
|---------|------|------|
| **ConfigMap** | `etcd-config` | etcd 配置 |
| **ConfigMap** | `user-service-config` | 用户服务配置 |
| **ConfigMap** | `product-service-config` | 产品服务配置 |
| **ConfigMap** | `trade-service-config` | 交易服务配置 |
| **ConfigMap** | `web-service-config` | Web 服务配置 |
| **Deployment** | `etcd` | etcd 数据库 |
| **Service** | `etcd-service` | etcd 服务发现 |
| **Deployment** | `user-service` | 用户 RPC 服务 (端口 9001) |
| **Deployment** | `product-service` | 产品 RPC 服务 (端口 9002) |
| **Deployment** | `trade-service` | 交易 RPC 服务 (端口 9003) |
| **Deployment** | `web-service` | Web API 网关 (端口 8888) |
| **Service** | `web-service` (NodePort 30888) | Web 服务对外暴露 |
| **Ingress** | `web-ingress` | Ingress 路由 |

---

## 六、架构图

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    K8sTest CR                           │
                    └─────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                                  │
│                                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                    │
│  │ user-service │     │product-service│    │trade-service │                    │
│  │   (gRPC)     │     │   (gRPC)     │     │   (gRPC)     │                    │
│  │   Port:9001  │     │   Port:9002  │     │   Port:9003  │                    │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘                    │
│         │                    │                    │                            │
│         └────────────────────┼────────────────────┘                            │
│                              │                                                  │
│                              ▼                                                  │
│                    ┌──────────────────┐                                        │
│                    │   web-service    │◄──── Ingress (service-test.example.com)│
│                    │   (HTTP API)     │                                        │
│                    │   Port: 8888     │                                        │
│                    │   NodePort:30888 │                                        │
│                    └────────┬─────────┘                                        │
│                             │                                                   │
│                             ▼                                                   │
│                    ┌──────────────────┐                                        │
│                    │      etcd        │                                        │
│                    │  Port: 2379      │                                        │
│                    │  (服务注册发现)   │                                        │
│                    └──────────────────┘                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 七、生成 CRD 和代码

```bash
# 生成 deepcopy 代码
make generate

# 生成 CRD YAML 和 RBAC 配置
make manifests
```

---

## 八、部署流程

### 8.1 安装 CRD

```bash
make install
# 或
kubectl apply -f config/crd/bases/apps.cncamp.io_k8stests.yaml
```

### 8.2 本地运行 (开发调试)

```bash
# 设置 kubeconfig
export KUBECONFIG=~/.kube/config

# 本地运行
go run ./cmd/main.go
```

### 8.3 部署到集群

```bash
# 构建镜像
make docker-build docker-push IMG=your-registry/k8s-test-operator:v1

# 部署
make deploy IMG=your-registry/k8s-test-operator:v1
```

### 8.4 创建 CR 测试

```bash
kubectl apply -f config/samples/apps_v1alpha1_k8stest.yaml
```

---

## 九、项目文件关系图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              用户操作                                         │
│                                  │                                          │
│                                  ▼                                          │
│                    kubectl apply -f k8stest.yaml                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes API Server                              │
│                                  │                                          │
│                    ┌─────────────┼─────────────┐                           │
│                    ▼             ▼             ▼                           │
│              ┌──────────┐ ┌──────────┐ ┌──────────┐                        │
│              │ CRD 定义  │ │ CR 实例  │ │ RBAC    │                        │
│              │(crd/bases)│ │(samples)│ │(rbac/)  │                        │
│              └──────────┘ └──────────┘ └──────────┘                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Operator                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         cmd/main.go                                  │   │
│  │  1. 初始化 Scheme (注册 CRD)                                         │   │
│  │  2. 创建 Manager                                                     │   │
│  │  3. 注册 Controller                                                  │   │
│  │  4. 启动 Manager                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                  │                                          │
│                                  ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                   internal/controller/                               │   │
│  │                                                                      │   │
│  │   Reconcile(ctx, req) → 监听 CR 变化                                  │   │
│  │        │                                                             │   │
│  │        ├── ensureEtcdConfigMap() → ConfigMap                         │   │
│  │        ├── ensureEtcd() → Deployment + Service                       │   │
│  │        ├── ensureRPCService() → Deployment + Service                 │   │
│  │        └── ensureWeb() → Deployment + Service + Ingress              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                  │                                          │
│                                  ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      api/v1alpha1/                                   │   │
│  │                                                                      │   │
│  │   K8sTestSpec {                                                      │   │
│  │       Namespace, ImageRegistry, ImageTag, Replicas, PullSecret       │   │
│  │   }                                                                  │   │
│  │   K8sTestStatus { Conditions }                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        创建的 Kubernetes 资源                                 │
│                                                                              │
│   ConfigMap: etcd-config, user-service-config, product-service-config...    │
│   Deployment: etcd, user-service, product-service, trade-service, web       │
│   Service: etcd-service, user-service, product-service...                   │
│   Ingress: web-ingress                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 十、关键概念总结

| 概念 | 说明 |
|------|------|
| **CRD** | Custom Resource Definition，定义自定义资源结构 |
| **CR** | Custom Resource，CRD 的实例 |
| **Controller** | 监听 CR 变化，执行 Reconcile 逻辑 |
| **Reconcile** | 协调循环，将实际状态调整为期望状态 |
| **OwnerReference** | 资源所有权，实现级联删除 |
| **CreateOrUpdate** | 幂等操作，存在则更新，不存在则创建 |
| **RBAC** | 权限控制，标记在 Controller 文件中 |

---

## 十一、使用示例

### CR 示例

```yaml
apiVersion: apps.cncamp.io/v1alpha1
kind: K8sTest
metadata:
  name: k8stest-sample
spec:
  namespace: service-test
  imageRegistry: crpi-j9gshcbjtb1i6c7h.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang
  imageTag: latest
  replicas: 2
  pullSecret: aliyun-cr
```

### 验证部署

```bash
# 查看 CR
kubectl get k8stest -A

# 查看创建的 Deployment
kubectl get deployments -n service-test

# 查看创建的 Service
kubectl get services -n service-test

# 查看 Ingress
kubectl get ingress -n service-test

# 访问 Web 服务
curl http://<node-ip>:30888
```

---

## 十二、与 Tenant Operator 的关系

推荐先由 Tenant Operator 创建并治理目标 namespace（配额/RBAC/secret 策略），k8s-test-operator 仅关注应用资源。

```
┌─────────────────────────────────────────────────────────────────┐
│                      Tenant Operator                             │
│  创建 Namespace、ResourceQuota、RoleBinding                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      K8sTest Operator                            │
│  在 Namespace 中部署微服务应用                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 十三、常见问题

### Q1: CRD 未安装

```
error: resource mapping not found for name: "k8stest-sample"
```

**解决方案：** 先安装 CRD

```bash
make install
```

### Q2: RBAC 权限不足

```
Error from server (Forbidden): deployments.apps is forbidden
```

**解决方案：** 确保 RBAC 配置正确

```bash
kubectl apply -f config/rbac/
```

### Q3: 镜像拉取失败

```
ImagePullBackOff
```

**解决方案：** 创建镜像拉取密钥

```bash
kubectl create secret docker-registry aliyun-cr \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>
```

---

## 十四、参考资源

- [Kubebuilder 官方文档](https://book.kubebuilder.io/introduction.html)
- [Controller Runtime 文档](https://pkg.go.dev/sigs.k8s.io/controller-runtime)
- [Kubernetes API 约定](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
