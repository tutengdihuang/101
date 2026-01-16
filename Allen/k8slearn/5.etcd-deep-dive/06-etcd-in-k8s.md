# K8s 中的 etcd - 探索集群的"记忆"

> 看看 K8s 到底在 etcd 里存了什么

## K8s etcd 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes 集群                           │
│                                                             │
│  ┌─────────────┐         ┌─────────────┐                   │
│  │ API Server  │────────▶│    etcd     │                   │
│  └─────────────┘         │  (静态Pod)  │                   │
│         │                └─────────────┘                   │
│         │                      │                           │
│         │                      │ 数据存储                   │
│         │                      ▼                           │
│         │                /registry/                        │
│         │                ├── pods/                         │
│         │                ├── deployments/                  │
│         │                ├── services/                     │
│         │                ├── configmaps/                   │
│         │                ├── secrets/                      │
│         │                └── ...                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 查看 K8s etcd 配置

### 查看 etcd Pod

```bash
# 查看 etcd Pod
kubectl get pods -n kube-system -l component=etcd

# 查看 etcd Pod 详情
kubectl get pod etcd-<node-name> -n kube-system -o yaml
```

**关键配置**：
```yaml
spec:
  containers:
  - command:
    - etcd
    - --advertise-client-urls=https://192.168.1.100:2379
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --client-cert-auth=true
    - --data-dir=/var/lib/etcd
    - --initial-advertise-peer-urls=https://192.168.1.100:2380
    - --initial-cluster=master=https://192.168.1.100:2380
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --listen-client-urls=https://127.0.0.1:2379,https://192.168.1.100:2379
    - --listen-peer-urls=https://192.168.1.100:2380
    - --name=master
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-client-cert-auth=true
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --snapshot-count=10000
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

---

## 连接 K8s etcd

### 方式一：进入 etcd Pod

```bash
# 进入 etcd Pod
kubectl exec -it etcd-<node-name> -n kube-system -- sh

# 设置别名
alias ectl='etcdctl --endpoints https://127.0.0.1:2379 \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key'

# 测试连接
ectl member list
```

### 方式二：从 Master 节点直接访问

```bash
# 设置环境变量
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# 测试连接
etcdctl member list -w table
```

---

## 探索 K8s 数据结构

### 查看所有 key

```bash
# 查看所有 key（只显示 key，不显示 value）
ectl get --prefix --keys-only /

# 查看 registry 下的所有 key
ectl get --prefix --keys-only /registry/
```

**实验输出**（部分）：
```
/registry/apiregistration.k8s.io/apiservices/v1.
/registry/apiregistration.k8s.io/apiservices/v1.apps
/registry/clusterrolebindings/cluster-admin
/registry/clusterroles/admin
/registry/configmaps/default/kube-root-ca.crt
/registry/configmaps/kube-system/coredns
/registry/deployments/default/nginx
/registry/namespaces/default
/registry/namespaces/kube-system
/registry/pods/default/nginx-xxx
/registry/secrets/default/default-token-xxx
/registry/services/endpoints/default/kubernetes
/registry/services/specs/default/kubernetes
...
```

### K8s 数据存储结构

```
/registry/
├── apiregistration.k8s.io/
│   └── apiservices/
├── clusterrolebindings/
├── clusterroles/
├── configmaps/
│   ├── default/
│   └── kube-system/
├── deployments/
│   └── default/
├── namespaces/
├── pods/
│   ├── default/
│   └── kube-system/
├── secrets/
├── services/
│   ├── endpoints/
│   └── specs/
└── ...
```

---

## 查看具体资源

### 查看 Service

```bash
# 查看 kube-dns Service
ectl get /registry/services/specs/kube-system/kube-dns -w=json
```

**实验输出**（简化）：
```json
{
  "header": {"revision": 12345},
  "kvs": [{
    "key": "/registry/services/specs/kube-system/kube-dns",
    "value": "<base64 encoded protobuf>"
  }]
}
```

注意：K8s 在 etcd 中存储的是 **Protobuf 编码**的数据，不是 JSON。

### 解码 K8s 数据

K8s 数据是 Protobuf 格式，需要特殊工具解码：

```bash
# 使用 auger 工具解码
# 安装：go install github.com/jpbetz/auger@latest

ectl get /registry/services/specs/kube-system/kube-dns | auger decode
```

或者直接通过 kubectl 查看：

```bash
kubectl get svc kube-dns -n kube-system -o yaml
```

---

## 实验：观察 K8s 操作

### 实验 1：Watch K8s 变化

```bash
# 终端 1：Watch etcd
ectl watch --prefix /registry/pods/default/

# 终端 2：创建 Pod
kubectl run nginx --image=nginx

# 终端 1 会看到 PUT 事件
```

### 实验 2：查看 Pod 创建过程

```bash
# 创建 Pod
kubectl run test-pod --image=busybox --command -- sleep 3600

# 查看 etcd 中的 Pod 数据
ectl get --prefix --keys-only /registry/pods/default/test-pod
```

### 实验 3：查看 ConfigMap

```bash
# 创建 ConfigMap
kubectl create configmap test-config --from-literal=key1=value1

# 在 etcd 中查看
ectl get /registry/configmaps/default/test-config
```

---

## K8s etcd 备份

### 备份脚本

```bash
#!/bin/bash
# k8s-etcd-backup.sh

BACKUP_DIR="/backup/etcd"
BACKUP_FILE="$BACKUP_DIR/k8s-etcd-$(date +%Y%m%d-%H%M%S).db"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save $BACKUP_FILE

# 验证备份
ETCDCTL_API=3 etcdctl snapshot status $BACKUP_FILE -w table

echo "Backup completed: $BACKUP_FILE"
```

### 恢复 K8s etcd

```bash
#!/bin/bash
# k8s-etcd-restore.sh

BACKUP_FILE=$1
DATA_DIR="/var/lib/etcd"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

# 停止 kubelet（会停止 etcd）
systemctl stop kubelet

# 备份当前数据
mv $DATA_DIR ${DATA_DIR}.bak.$(date +%Y%m%d-%H%M%S)

# 恢复数据
ETCDCTL_API=3 etcdctl snapshot restore $BACKUP_FILE \
  --data-dir=$DATA_DIR \
  --name=master \
  --initial-cluster=master=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# 修复权限
chown -R root:root $DATA_DIR

# 启动 kubelet
systemctl start kubelet

echo "Restore completed"
```

---

## 使用 Helm 部署 etcd 集群

### 安装 Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 部署 etcd

```bash
# 添加 bitnami 仓库
helm repo add bitnami https://charts.bitnami.com/bitnami

# 下载 chart
helm pull bitnami/etcd
tar -xvf etcd-*.tgz

# 修改配置（可选）
vi etcd/values.yaml

# 安装
helm install my-etcd ./etcd

# 或者直接安装（使用默认配置）
helm install my-etcd bitnami/etcd
```

### 连接 Helm 部署的 etcd

```bash
# 获取密码
export ETCD_ROOT_PASSWORD=$(kubectl get secret my-etcd -o jsonpath="{.data.etcd-root-password}" | base64 -d)

# 启动客户端 Pod
kubectl run my-etcd-client --restart='Never' \
  --image docker.io/bitnami/etcd:3.5.0 \
  --env ROOT_PASSWORD=$ETCD_ROOT_PASSWORD \
  --env ETCDCTL_ENDPOINTS="my-etcd.default.svc.cluster.local:2379" \
  --command -- sleep infinity

# 进入客户端
kubectl exec -it my-etcd-client -- bash

# 操作 etcd
etcdctl --user root:$ROOT_PASSWORD put /test "hello"
etcdctl --user root:$ROOT_PASSWORD get /test
```

---

## 安全注意事项

1. **不要直接修改 etcd 数据**：可能导致 K8s 状态不一致
2. **谨慎使用 delete**：删除数据可能导致集群故障
3. **定期备份**：etcd 数据是 K8s 的命脉
4. **限制访问**：etcd 应该只允许 API Server 访问

```bash
# ⚠️ 危险操作，仅用于学习
# 不要在生产环境执行！
ectl del --prefix /registry/pods/default/
```

---

## 核心要点

1. **K8s 数据存储在 /registry/ 下**
2. **数据格式是 Protobuf**，不是 JSON
3. **通过 TLS 证书认证**
4. **定期备份是必须的**
5. **不要直接修改 etcd 数据**

---

## 系列总结

恭喜你完成了 etcd 深入学习！回顾一下：

| 章节 | 核心内容 |
|------|---------|
| 基础操作 | put/get/watch/delete |
| 数据模型 | MVCC、Lease、事务 |
| 集群部署 | Raft 共识、高可用 |
| 备份恢复 | snapshot、restore |
| 运维实践 | 监控、压缩、碎片整理 |
| K8s 中的 etcd | 数据结构、备份恢复 |

etcd 是 K8s 的核心组件，理解它对于运维 K8s 集群至关重要。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[etcd 运维实践](05-operations.md)  
**返回目录**：[README](README.md)
