# Helm 基础操作 - 从安装到使用

> 手把手教你使用 Helm

## 一、安装 Helm

### macOS

```bash
# 使用 Homebrew
brew install helm
```

### Linux

```bash
# 使用脚本安装（推荐）
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 或者手动下载
wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

### 验证安装

```bash
helm version
# version.BuildInfo{Version:"v3.13.0", ...}
```

---

## 二、仓库管理

Helm 仓库就像应用商店，存放着各种 Chart。

### 添加仓库

```bash
# 添加官方稳定仓库（已废弃，使用 Bitnami）
helm repo add bitnami https://charts.bitnami.com/bitnami

# 添加其他常用仓库
helm repo add stable https://charts.helm.sh/stable
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 添加国内镜像（速度更快）
helm repo add azure http://mirror.azure.cn/kubernetes/charts/
helm repo add aliyun https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```

### 查看仓库列表

```bash
helm repo list
```

### 更新仓库

```bash
# 更新所有仓库
helm repo update

# 类似于 apt-get update
```

### 删除仓库

```bash
helm repo remove bitnami
```

---

## 三、搜索 Chart

### 搜索仓库中的 Chart

```bash
# 搜索 nginx
helm search repo nginx

# 搜索所有版本
helm search repo nginx --versions

# 搜索特定仓库
helm search repo bitnami/nginx
```

### 搜索 Artifact Hub（官方 Chart 中心）

```bash
helm search hub nginx
```

---

## 四、安装 Chart

### 基本安装

```bash
# 语法：helm install [RELEASE_NAME] [CHART]
helm install my-nginx bitnami/nginx

# 指定命名空间
helm install my-nginx bitnami/nginx -n production

# 创建命名空间（如果不存在）
helm install my-nginx bitnami/nginx -n production --create-namespace
```

### 查看 Chart 信息

```bash
# 查看 Chart 详情
helm show chart bitnami/nginx

# 查看 Chart 的 README
helm show readme bitnami/nginx

# 查看 Chart 的默认 values
helm show values bitnami/nginx
```

### 自定义配置安装

```bash
# 方式1：命令行参数
helm install my-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=LoadBalancer

# 方式2：使用 values 文件
helm install my-nginx bitnami/nginx -f custom-values.yaml

# 方式3：组合使用
helm install my-nginx bitnami/nginx \
  -f custom-values.yaml \
  --set image.tag=1.21.0
```

### 模拟安装（Dry Run）

```bash
# 不实际安装，只生成 YAML
helm install my-nginx bitnami/nginx --dry-run --debug
```

---

## 五、查看 Release

### 列出所有 Release

```bash
# 当前命名空间
helm list

# 所有命名空间
helm list -A

# 指定命名空间
helm list -n production
```

### 查看 Release 详情

```bash
# 查看 Release 状态
helm status my-nginx

# 查看 Release 使用的 values
helm get values my-nginx

# 查看 Release 生成的 YAML
helm get manifest my-nginx

# 查看 Release 的所有信息
helm get all my-nginx
```

---

## 六、升级 Release

### 基本升级

```bash
# 升级到新版本
helm upgrade my-nginx bitnami/nginx

# 升级并修改配置
helm upgrade my-nginx bitnami/nginx \
  --set replicaCount=5

# 使用新的 values 文件
helm upgrade my-nginx bitnami/nginx -f new-values.yaml
```

### 安装或升级（Install or Upgrade）

```bash
# 如果不存在就安装，存在就升级
helm upgrade --install my-nginx bitnami/nginx
```

### 查看升级历史

```bash
# 查看所有版本
helm history my-nginx

# 输出示例：
# REVISION  UPDATED                   STATUS      CHART         DESCRIPTION
# 1         Mon Jan 18 10:00:00 2026  superseded  nginx-13.2.0  Install complete
# 2         Mon Jan 18 11:00:00 2026  deployed    nginx-13.2.1  Upgrade complete
```

---

## 七、回滚 Release

### 回滚到上一个版本

```bash
helm rollback my-nginx
```

### 回滚到指定版本

```bash
# 回滚到版本 1
helm rollback my-nginx 1
```

### 模拟回滚

```bash
helm rollback my-nginx 1 --dry-run
```

---

## 八、卸载 Release

### 基本卸载

```bash
helm uninstall my-nginx
```

### 保留历史记录

```bash
# 卸载但保留历史（可以回滚）
helm uninstall my-nginx --keep-history
```

---

## 九、常用命令速查

| 命令 | 说明 | 示例 |
|------|------|------|
| `helm install` | 安装 Chart | `helm install my-app bitnami/nginx` |
| `helm list` | 列出 Release | `helm list -A` |
| `helm status` | 查看 Release 状态 | `helm status my-app` |
| `helm upgrade` | 升级 Release | `helm upgrade my-app bitnami/nginx` |
| `helm rollback` | 回滚 Release | `helm rollback my-app 1` |
| `helm uninstall` | 卸载 Release | `helm uninstall my-app` |
| `helm repo add` | 添加仓库 | `helm repo add bitnami https://...` |
| `helm repo update` | 更新仓库 | `helm repo update` |
| `helm search` | 搜索 Chart | `helm search repo nginx` |
| `helm show` | 查看 Chart 信息 | `helm show values bitnami/nginx` |

---

## 十、实战：安装 Nginx

### 步骤1：添加仓库

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 步骤2：查看 Chart

```bash
# 搜索 nginx
helm search repo nginx

# 查看默认配置
helm show values bitnami/nginx > nginx-values.yaml
```

### 步骤3：自定义配置

创建 `custom-values.yaml`：

```yaml
replicaCount: 2

service:
  type: LoadBalancer
  port: 80

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### 步骤4：安装

```bash
helm install my-nginx bitnami/nginx -f custom-values.yaml
```

### 步骤5：验证

```bash
# 查看 Release
helm list

# 查看 Pod
kubectl get pods

# 查看 Service
kubectl get svc

# 访问服务
kubectl port-forward svc/my-nginx 8080:80
# 浏览器访问 http://localhost:8080
```

### 步骤6：升级

```bash
# 修改副本数
helm upgrade my-nginx bitnami/nginx --set replicaCount=3
```

### 步骤7：回滚

```bash
# 查看历史
helm history my-nginx

# 回滚
helm rollback my-nginx
```

### 步骤8：卸载

```bash
helm uninstall my-nginx
```

---

## 十一、常见问题

### Q1: 如何查看 Chart 的所有可配置参数？

```bash
helm show values bitnami/nginx
```

### Q2: 如何在安装时覆盖多个参数？

```bash
helm install my-app bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=LoadBalancer \
  --set image.tag=1.21.0
```

### Q3: 如何查看 Release 使用的实际配置？

```bash
helm get values my-app
```

### Q4: 如何强制重新安装？

```bash
helm uninstall my-app
helm install my-app bitnami/nginx
```

### Q5: 如何查看 Helm 生成的 Kubernetes YAML？

```bash
helm get manifest my-app
```

---

## 核心要点总结

1. **安装 Helm**：使用脚本或包管理器
2. **仓库管理**：add、list、update、remove
3. **搜索 Chart**：search repo、search hub
4. **安装 Chart**：install、--set、-f
5. **管理 Release**：list、status、get
6. **升级回滚**：upgrade、rollback、history
7. **卸载**：uninstall

---

## 下一步

现在你已经掌握了 Helm 的基本操作，下一步学习如何创建自己的 Chart！

- Chart 的目录结构是什么？
- 如何创建自己的 Chart？
- 如何使用模板语法？

下一篇《Chart 开发》将带你深入 Helm Chart 的世界！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18
- 基于 Helm 版本：3.x

---

**上一篇**：[Helm 概览](01-helm-overview.md)  
**下一篇**：[Chart 开发](03-chart-development.md)
