# Joe 2.0 迁移指南

## 概述

Joe 2.0 重构了命令结构，提供更清晰的 CLI 体验，同时保持向后兼容。

**版本**: 1.x → 2.0  
**兼容性**: 旧命令继续工作，新命令提供更好的体验

---

## 主要变化

### 1. 命令结构

#### 旧版本（1.x）
```bash
./install.sh devtools --node
./install.sh devtools --claude
./install.sh mcp memory git
```

#### 新版本（2.0）
```bash
./install.sh tools install node
./install.sh tools install claude
./install.sh mcp install memory git
```

**关键改进**：
- 更清晰的域/动作结构
- 支持位置参数（不再需要 `--` 前缀）
- 自动依赖处理

### 2. 命令对照表

| 旧命令 | 新命令 | 说明 |
|--------|--------|------|
| `devtools` | `tools` | 重命名为更通用的名称 |
| `devtools --tui` | `tools` 或 `tools --tui` | 无参数默认进 TUI |
| `devtools --list` | `tools list` | 动作改为位置参数 |
| `devtools --node` | `tools install node` | 更清晰的语义 |
| `devtools --ai` | `tools install --ai` | 快捷组保留 |
| `configs` | `config` | 单数形式 |
| `repair-ghostty` | 保留原命令 (`repair-ghostty [--user-only]`) | 独立修复命令, 不属于 tools 域 |
| `bootstrap` | `quick-start` | 更清晰的名称 |

### 3. 新增功能

#### 自动依赖处理
```bash
# 旧版：手动记住顺序
./install.sh devtools --node
./install.sh devtools --claude

# 新版：自动提示并安装依赖
./install.sh tools install claude
# → 提示：需要 node，是否安装？[Y/n]

# 或显式要求
./install.sh tools install --with-deps claude
```

#### 位置参数支持
```bash
# 旧版：必须用 --
./install.sh devtools --claude --codex --gemini

# 新版：位置参数更简洁
./install.sh tools install claude codex gemini
```

#### 改进的状态显示
```bash
# 新增命令
./install.sh tools list      # 分组显示，标记已装/未装
./install.sh status          # 全局状态总览
```

#### 更好的 TUI
- 显示依赖关系
- 显示已安装版本
- 底部状态栏实时显示选择
- 新增按键：`d` 仅已装，`g` 按组选择

---

## 完整命令参考

### Shell 环境
```bash
# 不变
./install.sh shell
./install.sh shell --dry-run
./install.sh shell --no-fonts
```

### 开发工具 (Tools)

#### 列出和查看
```bash
./install.sh tools              # TUI 选择
./install.sh tools list         # 列出所有
./install.sh tools status       # 同上（别名）
```

#### 安装
```bash
# 单个组件
./install.sh tools install node
./install.sh tools install claude

# 多个组件
./install.sh tools install node claude codex

# 快捷组
./install.sh tools install --ai        # Claude + Codex
./install.sh tools install --all       # 全部

# 自动依赖
./install.sh tools install --with-deps claude
```

#### 更新
```bash
./install.sh tools update              # 统一更新全部工具
./install.sh tools update --dry-run    # 预览将执行的更新
```

更新走各工具的官方自更新机制。指定组件时 `tools update <组件>` 会转成
`update-all.sh --only <组件>`；没有自更新机制的组件（Zed、VS Code、Ghostty、
Brave）会被拒绝并提示用 `tools install <id>` 重装。

#### 检查
```bash
./install.sh tools check               # 系统兼容性
```

### MCP 服务器
```bash
./install.sh mcp                       # TUI 选择
./install.sh mcp list                  # 列出
./install.sh mcp install memory git    # 安装
./install.sh mcp update                # 更新
```

### Skills
```bash
./install.sh skills                    # 技能组选择
./install.sh skills list               # 列出
./install.sh skills install <组>       # 安装技能组
```

### 配置管理
```bash
./install.sh config list               # 查看映射
./install.sh config export             # 导出
./install.sh config import             # 导入
./install.sh config diff               # 对比
```

### 系统工具
```bash
./install.sh doctor                    # 环境检查
./install.sh doctor --json             # JSON 输出
./install.sh status                    # 所有组件状态
./install.sh status --short            # 单行汇总, 便于脚本
./install.sh update                    # 更新工具链与 joe 仓库
```

### 快捷命令
```bash
./install.sh quick-start               # 新手引导
./install.sh install-all               # 全部安装（需确认）
```

---

## 向后兼容性

### 保留的旧命令

以下旧命令**继续工作**，自动映射到新命令：

```bash
./install.sh devtools              # → tools
./install.sh devtools --node       # → tools install node
./install.sh configs list          # → config list
./install.sh repair-ghostty        # → scripts/repair_ghostty.sh
./install.sh bootstrap             # → quick-start
```

### Shell 参数兼容

```bash
# 这些旧参数继续工作
./install.sh --dry-run
./install.sh --no-fonts
./install.sh -u
# → 自动传递给 shell 命令
```

---

## 推荐迁移步骤

### 对于用户

1. **继续使用旧命令** — 一切照常工作
2. **逐步尝试新命令** — 更简洁、更智能
3. **使用 TUI 探索** — 看看新的分组和状态显示

### 对于脚本/CI

如果你在脚本或 CI 中使用 joe：

```bash
# 旧脚本继续工作
./install.sh devtools --node --claude

# 新脚本建议
./install.sh tools install --with-deps node claude
```

**建议**：在自动化环境中，明确指定 `--with-deps` 避免交互提示。

---

## 故障排除

### 问题：命令不识别

```bash
$ ./install.sh tools install xxx
未知组件: xxx
```

**解决**：使用 `./install.sh tools list` 查看可用组件名称。

### 问题：TUI 无法使用

```bash
错误: TUI 需要交互式终端
```

**解决**：在非交互环境（CI/脚本）中使用命令行方式：
```bash
./install.sh tools install <组件...>
```

### 问题：依赖提示不出现

**原因**：可能已经安装了依赖。

**验证**：
```bash
./install.sh tools list  # 查看 node 状态
```

---

## 反馈

发现问题或有建议？

- GitHub Issues: https://github.com/IotaHydrae/joe/issues
- 提交 PR 改进文档

---

**最后更新**: 2025-10-20  
**版本**: 2.0.0
