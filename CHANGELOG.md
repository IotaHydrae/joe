# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-01-08

### Added - Stage 2
- **安装进度指示**: install.sh 显示 `[X/Y]` 格式的步骤进度
- **智能步骤计算**: 根据命令行选项动态计算总步骤数
- **进度颜色**: 新增 CYAN 颜色用于进度消息
- **Bootstrap 阶段进度**: bootstrap.sh 显示 `[X/Y]` 格式的阶段进度
- **PROGRESS 日志级别**: 专门用于进度信息的日志级别

### Added - Stage 1
- **网络下载增强**: 下载重试时显示进度提示（第 X/3 次）
- **超时控制**: 为所有下载操作添加 300 秒超时限制，防止大文件下载卡死
- **大文件提示**: 下载超过 50MB 的文件时预先提示用户
- **Mint 兼容性检测**: 新增 `check_mint_compatibility()` 函数，检测 Linux Mint 特有的兼容性问题
- **系统环境检测**: doctor.sh 新增以下检测项：
  - 发行版支持状态（已验证/未测试）
  - Linux Mint Ubuntu 基线版本识别
  - 磁盘空间检查（警告阈值 5GB，推荐 10GB）
  - GitHub/npm registry 网络连接测试
- **前置依赖检查**: install.sh 和 install_devtools.sh 在安装前检查系统先决条件
  - 磁盘空间检查
  - 发行版兼容性验证
  - 必要工具检查（git, curl, build-essential 等）

### Changed
- **错误提示增强**: 下载失败时提供更详细的错误信息和重试提示
- **镜像下载优化**: 每个镜像失败时显示明确提示，方便用户了解进度
- **distro_report**: 在发行版报告中显示 Linux Mint 兼容性检测结果
- **doctor.sh 重组**: 将系统检测分为"系统信息与兼容性"、"系统资源"、"网络连接"三个部分
- **安装流程可视化**: 所有主要步骤都有进度指示

### Fixed
- 修复大文件下载可能无限期等待的问题（添加超时控制）
- 修复下载重试间隔过短的问题（从 2 秒改为 5 秒）
- 修复某些发行版上前置检查可能失败的问题

### Improved
- 所有下载操作的错误处理更加健壮
- Linux Mint 22.3 完全兼容性验证
- 用户反馈更加及时和清晰
- 安装过程透明度大幅提升

### Technical Details
- 修改文件: 6 个核心脚本
- 新增代码: 489 行（阶段一 219 行 + 阶段二 270 行）
- 删除代码: 27 行
- 测试通过: shellcheck 无警告，所有 dry-run 测试通过

### Verified On
- ✅ Linux Mint 22.3 (Zena) - noble base
- ✅ Ubuntu 24.04 (noble)
- ✅ Arch Linux (CachyOS)

## [Previous] - 2024-10-08

### Added
- 初始版本发布
- 跨发行版支持（apt/pacman/dnf/zypper）
- TUI 交互式组件选择
- MCP 服务器安装支持
- 代理技能管理
