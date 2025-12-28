# 项目文件

将此目录下的文件拷贝到 `service_test` 项目根目录：

```bash
cp Jenkinsfile /Volumes/mac_data/code/go_code/service_test/
```

然后推送到 GitHub：

```bash
cd /Volumes/mac_data/code/go_code/service_test
git add Jenkinsfile
git commit -m "add Jenkinsfile for Jenkins CI/CD"
git push
```

## 文件说明

- `Jenkinsfile` - Jenkins Pipeline 配置，定义构建、推送镜像、部署到 K8s 的流程

## 前置条件

在 Jenkins 中需要配置 Harbor 凭证：
1. Manage Jenkins → Credentials → Add
2. Kind: Username with password
3. Username: `admin`
4. Password: `Harbor12345`
5. ID: `harbor-credentials`
