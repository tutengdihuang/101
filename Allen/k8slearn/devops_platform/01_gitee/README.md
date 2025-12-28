# Gitee 同步配置

使用 Gitee 同步 GitHub 仓库，解决国内访问 GitHub 不稳定的问题。

## 仓库信息

| 项目 | 值 |
|------|-----|
| **Gitee 仓库** | `git@gitee.com:bitcash/service_test.git` |
| **HTTPS 地址** | `https://gitee.com/bitcash/service_test.git` |
| **GitHub 源仓库** | `https://github.com/tutengdihuang/service_test.git` |

## 为什么用 Gitee？

| 问题 | 解决方案 |
|------|----------|
| GitHub 访问不稳定 | Gitee 国内访问快 |
| Webhook 延迟高 | Gitee Webhook 稳定 |
| 代码拉取超时 | Gitee 秒级响应 |

## 配置步骤

### 1. 创建 Gitee 账号

访问 https://gitee.com 注册账号

### 2. 导入 GitHub 仓库

1. 登录 Gitee
2. 点击右上角 `+` → `从 GitHub 导入仓库`
3. 授权 GitHub 访问
4. 选择要导入的仓库 `tutengdihuang/service_test`
5. 点击导入

### 3. 配置自动同步

1. 进入 Gitee 仓库 `https://gitee.com/bitcash/service_test`
2. 管理 → 仓库镜像管理
3. 添加镜像：
   - 镜像方向：从 GitHub 拉取
   - 源仓库：`https://github.com/tutengdihuang/service_test.git`
   - 同步周期：每小时 / 手动

### 4. 配置 Webhook（用于 Tekton）

1. 进入 Gitee 仓库 → 管理 → WebHooks
2. 添加 Webhook：
   - URL: `http://<MASTER_IP>:31080` (Tekton EventListener)
   - 密码: 自定义 Secret
   - 事件: Push

## CI/CD 配置更新

### Tekton Pipeline 配置

```yaml
# 使用 Gitee 仓库地址
spec:
  params:
    - name: git-url
      value: https://gitee.com/bitcash/service_test.git
```

### 克隆仓库（私有仓库需要 Token）

```bash
# 公开仓库
git clone https://gitee.com/bitcash/service_test.git

# 私有仓库（使用 Personal Access Token）
git clone https://<USERNAME>:<TOKEN>@gitee.com/bitcash/service_test.git
```

## 验证

```bash
# 测试 Gitee 访问
git clone https://gitee.com/bitcash/service_test.git

# 应该秒级完成
```

## 注意事项

1. Gitee 免费版有仓库大小限制（1GB）
2. 同步有延迟（最快 5 分钟）
3. 私有仓库需要配置访问令牌
4. Webhook 格式与 GitHub 不同，Tekton Trigger 需要适配
