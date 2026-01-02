# Requirements Document

## Introduction

本功能旨在建立一个文件同步机制，确保 Kiro 工作空间中的文件修改能够安全、可靠地同步到用户的实际代码项目目录中。该机制禁止直接修改服务器上的内容或绕过同步流程直接修改代码文件。

## Glossary

- **Kiro_Workspace**: Kiro IDE 当前打开的工作目录
- **Target_Project**: 用户指定的实际代码项目目录（如 `/Volumes/mac_data/code/go_code/service_test`）
- **File_Sync_Service**: 负责将文件变更从 Kiro_Workspace 同步到 Target_Project 的服务
- **Change_Set**: 一组待同步的文件修改集合
- **Sync_Config**: 同步配置文件，定义源目录和目标目录的映射关系

## Requirements

### Requirement 1: 配置同步目标

**User Story:** As a developer, I want to configure the target project directory, so that file changes can be synced to the correct location.

#### Acceptance Criteria

1. THE Sync_Config SHALL store the target project path in `.kiro/sync-config.json`
2. WHEN a target path is configured, THE File_Sync_Service SHALL validate that the path exists and is writable
3. IF the target path does not exist, THEN THE File_Sync_Service SHALL return an error message indicating the path is invalid
4. THE Sync_Config SHALL support relative path patterns for file matching

### Requirement 2: 文件变更检测

**User Story:** As a developer, I want the system to detect file changes in the workspace, so that I know which files need to be synced.

#### Acceptance Criteria

1. WHEN a file is modified in Kiro_Workspace, THE File_Sync_Service SHALL add it to the Change_Set
2. WHEN a file is created in Kiro_Workspace, THE File_Sync_Service SHALL add it to the Change_Set
3. WHEN a file is deleted in Kiro_Workspace, THE File_Sync_Service SHALL mark it for deletion in the Change_Set
4. THE File_Sync_Service SHALL exclude files matching patterns in `.gitignore`

### Requirement 3: 同步执行

**User Story:** As a developer, I want to sync changes to my project directory, so that my actual codebase is updated.

#### Acceptance Criteria

1. WHEN the user triggers a sync operation, THE File_Sync_Service SHALL copy all files in Change_Set to Target_Project
2. THE File_Sync_Service SHALL preserve file permissions during sync
3. THE File_Sync_Service SHALL create parent directories if they do not exist in Target_Project
4. WHEN a sync completes successfully, THE File_Sync_Service SHALL clear the Change_Set
5. IF a sync fails, THEN THE File_Sync_Service SHALL report which files failed and why

### Requirement 4: 安全约束

**User Story:** As a developer, I want to ensure that only approved changes are synced, so that I maintain control over my codebase.

#### Acceptance Criteria

1. THE File_Sync_Service SHALL NOT directly modify files on remote servers
2. THE File_Sync_Service SHALL NOT bypass the sync mechanism to modify Target_Project files
3. WHEN syncing, THE File_Sync_Service SHALL create a backup of modified files in Target_Project
4. THE File_Sync_Service SHALL log all sync operations for audit purposes

### Requirement 5: 同步预览

**User Story:** As a developer, I want to preview changes before syncing, so that I can verify what will be modified.

#### Acceptance Criteria

1. WHEN the user requests a sync preview, THE File_Sync_Service SHALL display all pending changes
2. THE sync preview SHALL show file paths, change types (add/modify/delete), and diff summaries
3. THE user SHALL be able to selectively exclude files from the sync operation
