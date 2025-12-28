# Trivy 镜像漏洞扫描

Trivy 是一个简单易用的容器镜像漏洞扫描工具。

## 功能

- 容器镜像漏洞扫描
- 文件系统扫描
- Git 仓库扫描
- Kubernetes 配置扫描
- IaC 扫描（Terraform、CloudFormation）

## 使用方式

### 方式 1：命令行扫描

```bash
# 安装
apt-get install trivy

# 扫描镜像
trivy image harbor.example.com/service-test/user-service:v1

# 扫描并输出 JSON
trivy image -f json -o result.json harbor.example.com/service-test/user-service:v1
```

### 方式 2：集成到 Tekton

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: trivy-scan
spec:
  params:
  - name: IMAGE
    type: string
  - name: SEVERITY
    default: "HIGH,CRITICAL"
  steps:
  - name: scan
    image: aquasec/trivy:latest
    script: |
      trivy image \
        --severity $(params.SEVERITY) \
        --exit-code 1 \
        $(params.IMAGE)
```

### 方式 3：Harbor 集成

Harbor 内置 Trivy 扫描功能：

1. 登录 Harbor
2. 项目 → 配置
3. 启用 "自动扫描镜像"

## 扫描策略

| 严重级别 | 说明 | 建议 |
|----------|------|------|
| CRITICAL | 严重漏洞 | 必须修复 |
| HIGH | 高危漏洞 | 应该修复 |
| MEDIUM | 中危漏洞 | 建议修复 |
| LOW | 低危漏洞 | 可选修复 |

## CI/CD 集成示例

```yaml
# 在 Pipeline 中添加扫描步骤
- name: trivy-scan
  taskRef:
    name: trivy-scan
  params:
  - name: IMAGE
    value: "$(tasks.build.results.IMAGE_URL)"
  - name: SEVERITY
    value: "HIGH,CRITICAL"
```

如果发现高危漏洞，Pipeline 会失败，阻止镜像部署。

## 目录结构

```
07_trivy/
├── README.md
└── tekton/
    └── trivy-scan-task.yaml
```

## 最佳实践

1. **CI 阶段扫描**：构建后立即扫描
2. **阻断策略**：HIGH/CRITICAL 漏洞阻断部署
3. **定期扫描**：已部署镜像定期重新扫描
4. **基础镜像更新**：及时更新基础镜像
