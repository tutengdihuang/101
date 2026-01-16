# ConfigMap 与 Secret - 配置管理的艺术

> 把配置从代码中分离出来，让应用更灵活、更安全

## 为什么需要 ConfigMap？

传统方式，配置写在代码里或打包在镜像里：

```dockerfile
# 不好的做法：配置写死在镜像里
FROM nginx
COPY nginx.conf /etc/nginx/nginx.conf
```

问题：
- 改配置要重新构建镜像
- 不同环境（开发/测试/生产）要不同的镜像
- 敏感信息（密码）暴露在镜像里

**ConfigMap 和 Secret 解决了这些问题**：
- 配置和镜像分离
- 同一个镜像，不同配置
- 敏感信息加密存储

---

## ConfigMap vs Secret

| 特性 | ConfigMap | Secret |
|------|-----------|--------|
| 用途 | 存储普通配置 | 存储敏感信息 |
| 存储方式 | 明文 | Base64 编码 |
| 示例 | 数据库地址、日志级别 | 密码、API Key、证书 |
| 生活比喻 | 公告栏 | 保险箱 |

---

## 动手实验：创建 ConfigMap

### 方式一：从字面值创建

```bash
# 创建 ConfigMap
kubectl create configmap app-config \
  --from-literal=database_host=mysql.default.svc \
  --from-literal=database_port=3306 \
  --from-literal=log_level=INFO

# 查看 ConfigMap
kubectl get configmap app-config -o yaml
```

**实验输出**：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: mysql.default.svc
  database_port: "3306"
  log_level: INFO
```

### 方式二：从文件创建

```bash
# 创建配置文件
cat > game.properties << 'EOF'
enemies=aliens
lives=3
enemies.cheat=true
enemies.cheat.level=noGoodRotten
secret.code.passphrase=UUDDLRLRBABAS
secret.code.allowed=true
EOF

# 从文件创建 ConfigMap
kubectl create configmap game-config --from-file=game.properties

# 查看 ConfigMap
kubectl get configmap game-config -o yaml
```

**实验输出**：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-config
data:
  game.properties: |
    enemies=aliens
    lives=3
    enemies.cheat=true
    enemies.cheat.level=noGoodRotten
    secret.code.passphrase=UUDDLRLRBABAS
    secret.code.allowed=true
```

### 方式三：从环境文件创建

```bash
# 从环境文件创建（每行一个 key=value）
kubectl create configmap game-env-config --from-env-file=game.properties

# 查看 ConfigMap
kubectl get configmap game-env-config -o yaml
```

**实验输出**：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-env-config
data:
  enemies: aliens
  enemies.cheat: "true"
  enemies.cheat.level: noGoodRotten
  lives: "3"
  secret.code.allowed: "true"
  secret.code.passphrase: UUDDLRLRBABAS
```

**区别**：
- `--from-file`：整个文件作为一个 key
- `--from-env-file`：文件中每行作为一个 key-value

### 方式四：使用 YAML 创建

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: special-config
data:
  # 简单的 key-value
  special.how: very
  special.type: charm
  
  # 多行配置文件
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
        }
    }
```

```bash
kubectl apply -f configmap.yaml
```

---

## 动手实验：使用 ConfigMap

### 使用方式一：环境变量

```yaml
# env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-demo-pod
spec:
  containers:
  - name: demo
    image: nginx
    env:
    # 引用单个 key
    - name: SPECIAL_LEVEL
      valueFrom:
        configMapKeyRef:
          name: special-config
          key: special.how
    # 引用单个 key
    - name: SPECIAL_TYPE
      valueFrom:
        configMapKeyRef:
          name: special-config
          key: special.type
  restartPolicy: Never
```

```bash
# 创建 Pod
kubectl apply -f env-pod.yaml

# 查看环境变量
kubectl exec env-demo-pod -- env | grep SPECIAL
```

**实验输出**：
```
SPECIAL_LEVEL=very
SPECIAL_TYPE=charm
```

### 使用方式二：一次性导入所有环境变量

```yaml
# envfrom-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: envfrom-demo-pod
spec:
  containers:
  - name: demo
    image: nginx
    envFrom:
    - configMapRef:
        name: game-env-config
      prefix: GAME_    # 可选：添加前缀
  restartPolicy: Never
```

```bash
kubectl apply -f envfrom-pod.yaml
kubectl exec envfrom-demo-pod -- env | grep GAME
```

**实验输出**：
```
GAME_enemies=aliens
GAME_lives=3
GAME_enemies.cheat=true
...
```

### 使用方式三：挂载为 Volume

```yaml
# volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo-pod
spec:
  containers:
  - name: demo
    image: busybox
    command: ['sh', '-c', 'ls -la /etc/config && cat /etc/config/special.how && sleep 3600']
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: special-config
  restartPolicy: Never
```

```bash
kubectl apply -f volume-pod.yaml

# 查看挂载的文件
kubectl exec volume-demo-pod -- ls -la /etc/config
```

**实验输出**：
```
total 0
drwxrwxrwx    3 root     root          120 Jan 15 10:00 .
drwxr-xr-x    1 root     root           20 Jan 15 10:00 ..
lrwxrwxrwx    1 root     root           18 Jan 15 10:00 nginx.conf -> ..data/nginx.conf
lrwxrwxrwx    1 root     root           18 Jan 15 10:00 special.how -> ..data/special.how
lrwxrwxrwx    1 root     root           19 Jan 15 10:00 special.type -> ..data/special.type
```

每个 key 变成了一个文件！

```bash
# 查看文件内容
kubectl exec volume-demo-pod -- cat /etc/config/special.how
```

**实验输出**：
```
very
```

---

## ConfigMap 热更新

当 ConfigMap 以 Volume 方式挂载时，更新 ConfigMap 后，Pod 内的文件会自动更新（有延迟，通常 1-2 分钟）。

### 实验：验证热更新

```bash
# 更新 ConfigMap
kubectl patch configmap special-config -p '{"data":{"special.how":"extremely"}}'

# 等待 1-2 分钟后查看
kubectl exec volume-demo-pod -- cat /etc/config/special.how
```

**实验输出**：
```
extremely
```

**注意**：环境变量方式不支持热更新，需要重启 Pod。

---

## 动手实验：Downward API

Downward API 让 Pod 可以获取自己的元数据（名称、命名空间、标签等）。

```yaml
# downward-api-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: downward-api-pod
  labels:
    app: demo
    version: v1
spec:
  containers:
  - name: demo
    image: busybox
    command: ['sh', '-c', 'echo "Pod Name: $POD_NAME" && echo "Pod IP: $POD_IP" && echo "Node Name: $NODE_NAME" && sleep 3600']
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
  restartPolicy: Never
```

```bash
kubectl apply -f downward-api-pod.yaml
kubectl logs downward-api-pod
```

**实验输出**：
```
Pod Name: downward-api-pod
Pod IP: 10.244.1.15
Node Name: node1
```

---

## Secret：存储敏感信息

### 创建 Secret

```bash
# 从字面值创建
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=S3cr3t!

# 查看 Secret（注意：值是 Base64 编码的）
kubectl get secret db-secret -o yaml
```

**实验输出**：
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: UzNjcjN0IQ==    # Base64 编码
  username: YWRtaW4=        # Base64 编码
```

```bash
# 解码查看
echo "UzNjcjN0IQ==" | base64 -d
# 输出: S3cr3t!
```

### 使用 Secret

```yaml
# secret-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo-pod
spec:
  containers:
  - name: demo
    image: busybox
    command: ['sh', '-c', 'echo "Username: $DB_USER" && echo "Password: $DB_PASS" && sleep 3600']
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
  restartPolicy: Never
```

```bash
kubectl apply -f secret-pod.yaml
kubectl logs secret-demo-pod
```

**实验输出**：
```
Username: admin
Password: S3cr3t!
```

---

## 三种使用方式对比

| 方式 | 适用场景 | 热更新 | 示例 |
|------|---------|--------|------|
| 环境变量 | 简单配置 | ❌ 不支持 | 数据库地址、端口 |
| Volume 挂载 | 配置文件 | ✅ 支持 | nginx.conf、app.yaml |
| Downward API | Pod 元数据 | ❌ 不支持 | Pod 名称、IP |

---

## 清理实验环境

```bash
kubectl delete pod env-demo-pod envfrom-demo-pod volume-demo-pod downward-api-pod secret-demo-pod
kubectl delete configmap app-config game-config game-env-config special-config
kubectl delete secret db-secret
rm -f game.properties configmap.yaml env-pod.yaml envfrom-pod.yaml volume-pod.yaml downward-api-pod.yaml secret-pod.yaml
```

---

## 核心要点总结

1. **ConfigMap**：存储普通配置，明文存储
2. **Secret**：存储敏感信息，Base64 编码
3. **创建方式**：
   - `--from-literal`：从字面值
   - `--from-file`：从文件（整个文件作为一个 key）
   - `--from-env-file`：从环境文件（每行一个 key-value）
   - YAML 文件
4. **使用方式**：
   - 环境变量：简单配置，不支持热更新
   - Volume 挂载：配置文件，支持热更新
   - Downward API：获取 Pod 元数据
5. **最佳实践**：
   - 配置和代码分离
   - 敏感信息用 Secret
   - 需要热更新用 Volume 挂载

记住这个比喻：**ConfigMap 是公告栏，Secret 是保险箱**。

---

## 下一步

配置管理解决了，但如何知道应用是否健康？如何实现优雅的滚动更新？

下一篇我们学习探针（Probe），它是 K8s 的健康检查机制。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[Deployment 详解](02-deployment.md)  
**下一篇**：[探针与健康检查](04-probes.md)
