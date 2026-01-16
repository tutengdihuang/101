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
- ❌ **删除用户的实验文档和学习笔记**（见下方详细规则）

## 实验文档保护规则（重要！）

### 绝对禁止删除的文件类型

以下类型的文件**绝对不能删除**，只能新增或修改：

1. **实验文档**：
   - `实验说明.md`、`*-demo.md`、`*-lab.md`
   - `labs/` 目录下的所有文件
   - `experiments/` 目录下的所有文件
   - 任何包含 "实验"、"lab"、"demo"、"experiment" 的文件

2. **用户学习笔记**：
   - `*指南*.md`、`*完全指南*.md`
   - `COMPLETED.md`、`README.md`
   - `quick-reference.md`、`troubleshooting.md`
   - 用户手写的总结文档

3. **部署配置**：
   - `deployments/` 目录下的所有文件
   - `scripts/` 目录下的所有文件
   - `*.yaml`、`*.yml` 配置文件

### 整理文档时的正确做法

当需要整理或重构文档时：

```
✅ 正确做法：
1. 新建文件夹存放新内容（如 labs-new/）
2. 保留原有文件不动
3. 在 README.md 中添加新内容的链接
4. 询问用户是否需要合并或删除旧内容

❌ 错误做法：
1. 直接删除原有文件
2. 用新文件覆盖原有文件
3. 未经确认就重命名或移动文件
```

### 删除文件前必须确认

如果确实需要删除文件，必须：

1. **明确列出**要删除的文件列表
2. **询问用户确认**："以下文件将被删除，是否确认？"
3. **等待用户明确同意**后才能执行删除
4. **建议备份**：提醒用户先备份重要文件

### 恢复误删文件

如果不小心删除了文件，立即使用 Git 恢复：

```bash
# 恢复单个文件
git checkout HEAD -- "path/to/deleted/file.md"

# 恢复整个目录
git checkout HEAD -- "path/to/deleted/directory/"

# 查看被删除的文件
git status
```

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
