# Chart 开发 - 创建自己的 Helm Chart

> 从零开始创建一个 Helm Chart

## 一、Chart 是什么？

Chart 就像一个菜谱，包含了制作一道菜（部署一个应用）所需的所有材料和步骤。

```
Chart = 配方（模板） + 材料清单（values） + 说明书（README）
```

---

## 二、Chart 目录结构

### 创建一个 Chart

```bash
helm create myapp
```

### 目录结构

```
myapp/
├── Chart.yaml          # Chart 的元数据
├── values.yaml         # 默认配置值
├── charts/             # 依赖的其他 Chart
├── templates/          # Kubernetes 资源模板
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # 模板辅助函数
│   ├── NOTES.txt       # 安装后的提示信息
│   └── tests/          # 测试文件
│       └── test-connection.yaml
└── .helmignore         # 打包时忽略的文件
```

---

## 三、Chart.yaml - Chart 的身份证

```yaml
apiVersion: v2                    # Chart API 版本（v2 for Helm 3）
name: myapp                       # Chart 名称
description: A Helm chart for my application
type: application                 # application 或 library
version: 0.1.0                    # Chart 版本
appVersion: "1.0.0"              # 应用版本

# 可选字段
keywords:
  - web
  - nginx
home: https://example.com
sources:
  - https://github.com/example/myapp
maintainers:
  - name: Your Name
    email: your@email.com
```

### 字段说明

| 字段 | 说明 | 必填 |
|------|------|------|
| apiVersion | Chart API 版本 | ✅ |
| name | Chart 名称 | ✅ |
| version | Chart 版本 | ✅ |
| appVersion | 应用版本 | ❌ |
| description | 描述 | ❌ |
| type | application/library | ❌ |

---

## 四、values.yaml - 配置参数

`values.yaml` 是 Chart 的配置文件，定义了所有可配置的参数。

```yaml
# 副本数
replicaCount: 1

# 镜像配置
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.21.0"

# Service 配置
service:
  type: ClusterIP
  port: 80

# Ingress 配置
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific

# 资源限制
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

---

## 五、templates/ - Kubernetes 资源模板

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "myapp.selectorLabels" . | nindent 4 }}
```

---

## 六、_helpers.tpl - 模板辅助函数

`_helpers.tpl` 定义可复用的模板片段。

```yaml
{{/*
生成完整名称
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
生成通用标签
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
生成选择器标签
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

---

## 七、实战：创建一个简单的 Web 应用 Chart

### 步骤1：创建 Chart

```bash
helm create webapp
cd webapp
```

### 步骤2：修改 Chart.yaml

```yaml
apiVersion: v2
name: webapp
description: A simple web application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### 步骤3：修改 values.yaml

```yaml
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.21.0"

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### 步骤4：验证 Chart

```bash
# 检查语法
helm lint webapp

# 模拟安装（查看生成的 YAML）
helm install --dry-run --debug my-webapp ./webapp
```

### 步骤5：安装 Chart

```bash
helm install my-webapp ./webapp
```

### 步骤6：验证部署

```bash
# 查看 Release
helm list

# 查看 Pod
kubectl get pods

# 查看 Service
kubectl get svc
```

---

## 八、Chart 依赖管理

### 添加依赖

在 `Chart.yaml` 中添加：

```yaml
dependencies:
  - name: mysql
    version: "9.3.0"
    repository: "https://charts.bitnami.com/bitnami"
  - name: redis
    version: "17.0.0"
    repository: "https://charts.bitnami.com/bitnami"
```

### 下载依赖

```bash
helm dependency update
```

这会在 `charts/` 目录下载依赖的 Chart。

### 覆盖依赖的配置

在 `values.yaml` 中：

```yaml
mysql:
  auth:
    rootPassword: "mypassword"
    database: "mydb"

redis:
  auth:
    password: "redispass"
```

---

## 九、打包和分发 Chart

### 打包 Chart

```bash
helm package webapp
# 生成 webapp-0.1.0.tgz
```

### 安装打包的 Chart

```bash
helm install my-webapp webapp-0.1.0.tgz
```

### 推送到 Chart 仓库

```bash
# 推送到 Harbor
helm push webapp-0.1.0.tgz oci://harbor.example.com/charts

# 推送到 ChartMuseum
curl --data-binary "@webapp-0.1.0.tgz" http://chartmuseum.example.com/api/charts
```

---

## 十、Chart 最佳实践

### 1. 命名规范

```yaml
# 使用小写字母和连字符
name: my-app        # ✅
name: MyApp         # ❌
name: my_app        # ❌
```

### 2. 版本管理

```yaml
# Chart 版本：遵循语义化版本
version: 1.2.3      # 主版本.次版本.修订号

# 应用版本：应用的实际版本
appVersion: "2.0.1"
```

### 3. 默认值原则

```yaml
# values.yaml 应该提供合理的默认值
replicaCount: 1     # ✅ 默认单副本
replicaCount: 100   # ❌ 默认值太大
```

### 4. 文档化

```yaml
# values.yaml 中添加注释
# 副本数量
replicaCount: 1

# 镜像配置
image:
  # 镜像仓库地址
  repository: nginx
  # 镜像拉取策略
  pullPolicy: IfNotPresent
```

---

## 核心要点总结

1. **Chart 结构**：Chart.yaml + values.yaml + templates/
2. **Chart.yaml**：定义 Chart 的元数据
3. **values.yaml**：定义可配置的参数
4. **templates/**：Kubernetes 资源模板
5. **_helpers.tpl**：可复用的模板片段
6. **依赖管理**：通过 dependencies 管理
7. **打包分发**：helm package + helm push

---

## 下一步

现在你已经学会了创建 Chart，下一步学习 Helm 的模板语法！

- 如何使用变量和函数？
- 如何实现条件判断和循环？
- 如何使用内置对象？

下一篇《模板语法》将深入讲解 Helm 模板的强大功能！

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18
- 基于 Helm 版本：3.x

---

**上一篇**：[Helm 基础操作](02-helm-basics.md)  
**下一篇**：[模板语法](04-template-syntax.md)
