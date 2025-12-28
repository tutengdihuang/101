# SonarQube 代码质量扫描

SonarQube 用于代码质量分析，检测 Bug、漏洞、代码异味。

## 功能

- 代码质量分析
- 安全漏洞检测
- 代码覆盖率
- 重复代码检测
- 技术债务评估

## 部署步骤

### 1. 创建命名空间

```bash
kubectl create namespace sonarqube
```

### 2. 部署 PostgreSQL

```yaml
# sonarqube-postgres.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube-postgres
  namespace: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube-postgres
  template:
    metadata:
      labels:
        app: sonarqube-postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_USER
          value: sonar
        - name: POSTGRES_PASSWORD
          value: sonar123
        - name: POSTGRES_DB
          value: sonarqube
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        emptyDir: {}
```

### 3. 部署 SonarQube

```yaml
# sonarqube-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      containers:
      - name: sonarqube
        image: sonarqube:lts-community
        env:
        - name: SONAR_JDBC_URL
          value: jdbc:postgresql://sonarqube-postgres:5432/sonarqube
        - name: SONAR_JDBC_USERNAME
          value: sonar
        - name: SONAR_JDBC_PASSWORD
          value: sonar123
        ports:
        - containerPort: 9000
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
```

### 4. 创建 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  type: NodePort
  ports:
  - port: 9000
    nodePort: 30900
  selector:
    app: sonarqube
```

### 5. 访问

```
http://<MASTER_IP>:30900
默认账号: admin / admin
```

## 集成 Tekton

在 Tekton Pipeline 中添加 SonarQube 扫描 Task：

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: sonar-scan
spec:
  params:
  - name: SONAR_HOST_URL
    default: "http://sonarqube.sonarqube:9000"
  - name: SONAR_TOKEN
    type: string
  steps:
  - name: scan
    image: sonarsource/sonar-scanner-cli
    script: |
      sonar-scanner \
        -Dsonar.host.url=$(params.SONAR_HOST_URL) \
        -Dsonar.login=$(params.SONAR_TOKEN) \
        -Dsonar.projectKey=service-test
```

## 目录结构

```
06_sonarqube/
├── README.md
├── install/
│   ├── sonarqube-postgres.yaml
│   ├── sonarqube-deployment.yaml
│   └── sonarqube-service.yaml
└── tekton/
    └── sonar-scan-task.yaml
```
