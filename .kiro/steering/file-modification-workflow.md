# File Modification Workflow

## 规则说明

本规则定义了 Kiro 在修改文件时必须遵循的工作流程，确保所有变更都通过安全、可追溯的方式进行。

## 核心原则

1. **禁止直接修改**：不得直接修改目标项目目录或服务器上的文件
2. **本地优先**：所有修改必须先在 Kiro 工作空间中完成
3. **显式同步**：通过明确的上传/同步操作将变更应用到目标位置

## 工作流程

### 修改文件时

1. 在 Kiro 工作空间中创建或修改文件
2. 完成修改后，提示用户进行同步操作
3. 用户确认后，通过以下方式之一同步：
   - 手动复制文件到目标项目
   - 使用 `rsync` 或 `cp` 命令同步
   - 通过 Git 提交并推送

### 同步命令示例

```bash
# 同步单个文件到目标项目
cp <workspace_file> /Volumes/mac_data/code/go_code/service_test/<target_path>

# 同步整个目录
rsync -av --exclude='.kiro' ./ /Volumes/mac_data/code/go_code/service_test/

# 使用 Git 方式
git add .
git commit -m "Update files"
git push
```

## 禁止的操作

- ❌ 直接修改 `/Volumes/mac_data/code/go_code/service_test/` 中的文件
- ❌ 直接通过 SSH/SCP 修改服务器文件
- ❌ 绕过本地工作空间直接写入目标位置

## 允许的操作

- ✅ 在 Kiro 工作空间中创建/修改文件
- ✅ 提示用户手动同步文件
- ✅ 生成同步命令供用户执行
- ✅ 通过 Git 工作流提交变更

## 同步提示模板

当完成文件修改后，使用以下提示：

```
文件已在工作空间中修改：
- <file_path>

请使用以下命令同步到目标项目：
cp <workspace_file> /Volumes/mac_data/code/go_code/service_test/<target_path>

或者提交到 Git：
git add <file_path>
git commit -m "<commit_message>"
git push
```
