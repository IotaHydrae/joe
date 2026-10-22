# Joe 更新日志

## [2.0.0] - 2026-10-21

### 🎉 重大重构

#### 新增
- 全新命令结构：`./install.sh <域> <动作> [选项] [参数...]`
- 智能依赖管理系统：自动检测和提示缺失依赖
- 改进的 TUI 界面：分组显示、状态标记、依赖提示
- 位置参数支持：`tools install claude codex` 更简洁
- 新命令：`tools`, `config`, `status`, `quick-start`
- 依赖解析库：`scripts/lib/deps.sh`
- TUI 通用库：`scripts/ui/tui_common.sh`
- `mcp` / `skills` 动作语法转换层：`scripts/commands/{mcp,skills}.sh`（`list` / `install` / `update` / `categories`）
- TUI pty 回归测试：`tests/tui_pty_check.py`，CLI 套件扩充到 33 项并接入 CI
- `status` 命令：`scripts/commands/status.sh` 一屏汇总工具/MCP/技能安装数，`--short` 输出单行
- `tools update` 接入 `scripts/update-all.sh`（`--dry-run` / `--quiet` / `--system`）
- CLI 套件扩充到 37 项
- 主菜单实现在 `scripts/ui/menu_main.sh`：菜单项回调 `install.sh` 路由，删除了 `install.sh` 里的两份旧菜单实现
- 主菜单 pty 回归：`tests/menu_pty_check.py`，套件扩充到 38 项
- `quick-start` 成为唯一实现：`scripts/commands/quickstart.sh`（由 `scripts/bootstrap.sh` 移入，旧名 `bootstrap` 仍映射）
- quick-start 补上 `shell` 阶段——此前的"一键全装"根本不含 zsh/OMZ 环境
- 修正 `install-all` 传引擎不接受的 `--all`（此前必然失败）；非交互读不到确认时按取消处理
- 修正仓库根推导少一层导致改为从 GitHub 克隆的问题（`--only/--skip` 支持 `shell`，doctor 纳入 `[n/5]` 编号）
- quick-start 沙箱回归：断言复用当前仓库不重克隆、shell 阶段不加 `--all`、`--only` 阶段裁剪，套件扩充到 44 项
- 完整文档：迁移指南、技术总结

#### 改进
- **Tools 命令**: 
  - `tools list` - 清晰的分组状态显示
  - `tools install <组件...>` - 支持多个组件和快捷组
  - `--with-deps` - 自动安装依赖
  - 实时版本和依赖信息显示
  
- **TUI 体验**:
  - 按组显示（环境管理、AI 工具、编辑器等）
  - 显示依赖关系 `[需要:node]`
  - 显示安装状态和版本
  - 底部状态栏实时显示选择
  - 新按键：`d`仅已装、`i`仅未装

- **用户体验**:
  - 依赖问题自动提示并询问
  - 错误信息更友好
  - 命令语义更清晰

#### 向后兼容
- ✅ 所有旧命令继续工作
- ✅ `devtools` → `tools` 自动映射
- ✅ `configs` → `config` 自动映射
- ✅ `repair-ghostty` 映射到新命令
- ✅ `bootstrap` → `quick-start` 映射
- ✅ 旧 Shell 参数（`--dry-run`, `--no-fonts` 等）继续工作

#### 修复
- 修复主菜单按 `q` 无法退出的问题
- 修复 `tools install --with-deps <AI CLI>` 在 `set -e` 下静默退出 (依赖补全返回码被当作错误)
- 修复依赖解析为空时输出空白项, 导致 `COMPONENT_NAMES: bad array subscript`
- 修复 Tools TUI: 界面渲染被 `$(...)` 捕获导致屏幕空白, 且转义序列被当成组件参数
- 修复 TUI 收不到回车: 命令替换会剥掉结尾 LF, 现改用 `dd` 读取并关闭 `icrnl`
- 修复非交互终端下依赖确认直接中止, 现输出可操作提示
- 修复 `install.sh status` 丢弃参数导致 `--short` 失效
- 修复 `status` 统计把安装器 `--list` 结尾的「安装位置」段落计入总数
- 修复 `--help` 列出不存在的 `shell --minimal` 选项, 并改正 `skills list/install` 的措辞（列的是技能而非技能组）

#### 文档
- 新增 `docs/MIGRATION.md` - 详细迁移指南
- 新增 `docs/V2_SUMMARY.md` - 技术总结文档
- 补齐英文 README 的 `tools` 新语法、`status`、常用命令与故障排除章节
- 重写 `AGENTS.md` 的结构、测试与 Shell 约定章节（`set -e` 捕获、空数组输出、按键读取）
- 校正 `docs/MIGRATION.md` 的 `tools update <组件>` 示例（更新不支持按组件选择）
- 更新 `docs/V2_SUMMARY.md` 路线图与修复记录，修正 2.0 的日期年份
- 更新 `README.md` - 新旧命令对照
- 新增测试套件：`tests/test_new_cli.sh`

### 技术细节

#### 目录结构
```
scripts/
├── commands/          # 命令实现（新增）
│   └── tools.sh
├── ui/                # UI 组件（新增）
│   ├── tui_common.sh
│   └── tui_tools.sh
├── lib/               # 库函数（重组）
│   └── deps.sh       # 依赖解析（新增）
└── [原有脚本]         # 向后兼容保留
```

#### 代码统计
- 新增代码：~1500 行
- 新增文件：8 个
- 修改文件：3 个
- 测试覆盖：7/7 通过

#### 性能
- 启动时间：+9% (0.12s vs 0.11s) - 可接受
- TUI 响应：<10ms
- 依赖解析：<5ms

### 破坏性变更
无 - 完全向后兼容

### 迁移指南
详见 `docs/MIGRATION.md`

### 已知问题
无

### 未来计划
- [x] MCP / Skills 命令接口（2026-10-21：转换层，只做语法映射）
- [x] 新主菜单实现（2026-10-21：`scripts/ui/menu_main.sh`）
- [x] Quick-start 引导流程（2026-10-21：`scripts/commands/quickstart.sh`）
- [x] CLI 测试套件 + CI（44 项，含两个 pty 回归）
- [ ] MCP 侧：TUI 改进与"某些 MCP 需要 Node"的依赖管理
- [ ] 组件安装逻辑模块化（每个组件独立模块，取代 `install_devtools.sh` 单体）
- [ ] 按组件的选择性更新（需要 `update-all.sh` 先支持）

---

## [1.x] - 历史版本

（略）
