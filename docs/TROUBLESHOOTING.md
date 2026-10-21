# Joe 故障排除指南

## 常见问题

### 1. Ghostty 终端中菜单按 q 无法退出

**症状**：
- 在 Ghostty 中运行 `./install.sh`，按 `q` + 回车后菜单不退出
- 在其他终端（Tabby、Alacritty 等）中正常

**原因**：
Ghostty 将 `TERM` 环境变量设置为 `dumb`，导致终端交互功能受限。

**诊断**：
```bash
echo $TERM
# 如果显示 "dumb"，则是此问题
```

**快速修复**：
```bash
# 方法 1：自动修复（推荐）
bash scripts/fix_ghostty_term.sh

# 方法 2：手动修复
echo "term = xterm-256color" >> ~/.config/ghostty/config

# 修复后重启 Ghostty
```

**详细说明**：查看 [GHOSTTY_FIX.md](GHOSTTY_FIX.md)

---

### 2. 依赖安装提示但没有自动安装

**症状**：
```bash
$ ./install.sh tools install claude
警告: 需要 node 作为依赖
是否安装？[Y/n] y
[但没有实际安装]
```

**原因**：
当前实现仍然调用旧的安装脚本，依赖处理还在迁移中。

**临时解决**：
```bash
# 手动先装依赖
./install.sh tools install node
# 再装目标组件
./install.sh tools install claude
```

**未来版本**：将在 2.1.0 完全重构安装逻辑。

---

### 3. TUI 界面显示错乱

**症状**：
- TUI 界面布局混乱
- 光标位置不对
- 颜色显示异常

**诊断**：
```bash
# 检查终端类型
echo $TERM

# 检查终端尺寸
stty size

# 检查 terminfo
infocmp $TERM | head
```

**解决**：

**问题 1: TERM=dumb**
```bash
# 参考问题 1 的修复方法
```

**问题 2: 终端太小**
```bash
# TUI 需要至少 80x24
# 调整终端窗口大小
```

**问题 3: terminfo 缺失**
```bash
# 安装完整的 terminfo 数据库
sudo apt install ncurses-term   # Debian/Ubuntu
sudo dnf install ncurses-term    # Fedora
```

---

### 4. 旧命令不工作了

**症状**：
```bash
$ ./install.sh devtools --node
未知选项: --node
```

**原因**：
可能使用了错误的参数格式。

**检查**：
```bash
# 新命令（推荐）
./install.sh tools install node

# 旧命令（仍然支持）
./install.sh devtools --node
# 注意：没有 "install" 子命令
```

**说明**：
旧命令直接用 `--node`，新命令需要 `install node`。
如果旧命令不工作，请报告 bug。

---

### 5. 权限错误

**症状**：
```bash
Permission denied
```

**解决**：

**情况 1: install.sh 不可执行**
```bash
chmod +x install.sh
```

**情况 2: 系统包管理需要 sudo**
```bash
# 正常现象，会自动提示输入密码
```

**情况 3: 文件写入失败**
```bash
# 检查目录权限
ls -la ~/.config
ls -la ~/.local
```

---

### 6. curl 或 git 命令不存在

**症状**：
```bash
command not found: git
command not found: curl
```

**解决**：
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install git curl

# Fedora
sudo dnf install git curl

# Arch
sudo pacman -S git curl
```

---

### 7. 安装后命令找不到

**症状**：
```bash
$ claude
command not found: claude
```

**原因**：
PATH 未更新或需要重新加载 shell。

**解决**：
```bash
# 方法 1: 重新加载 shell 配置
source ~/.zshrc    # 如果用 zsh
source ~/.bashrc   # 如果用 bash

# 方法 2: 重启终端

# 方法 3: 检查 PATH
echo $PATH | tr ':' '\n' | grep -E "(nvm|local/bin)"
```

---

### 8. nvm 命令不可用

**症状**：
```bash
$ nvm --version
command not found: nvm
```

**说明**：
这是预期行为。Joe 的设计是：
- nvm 安装到 `~/.nvm`
- 但**不加载** nvm shell 函数（避免拖慢 shell 启动）
- 直接使用 `~/.nvm/current/bin` 中的 node

**如果需要 nvm 命令**：
```bash
# 临时加载
source ~/.nvm/nvm.sh

# 或永久加载（不推荐，会拖慢启动）
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
```

---

### 9. Python 版本切换问题

**症状**：
pyenv 已安装但 Python 版本没变

**说明**：
Joe 只安装 pyenv，不自动安装 Python 版本（让用户自己选）。

**手动安装 Python**：
```bash
# 列出可用版本
pyenv install --list

# 安装指定版本
pyenv install 3.11.5

# 设置全局版本
pyenv global 3.11.5

# 验证
python --version
```

---

### 10. MCP 配置未生效

**症状**：
运行 `./install.sh mcp install memory` 后，Claude Code 中看不到 memory 服务。

**检查**：
```bash
# 检查配置文件
cat ~/.config/Claude/claude_desktop_config.json

# 或
cat ~/.config/Code/User/globalStorage/settings.json
```

**解决**：
```bash
# 重启 Claude Code 或相关编辑器

# 如果仍然不行，手动检查配置格式
jq . ~/.config/Claude/claude_desktop_config.json
```

---

## 获取帮助

### 1. 查看日志

```bash
# 检查安装日志
cat install.log

# 如果使用了 --dry-run
./install.sh shell --dry-run
```

### 2. 运行诊断

```bash
# 环境检查
./install.sh doctor

# 组件状态
./install.sh tools list
./install.sh mcp list
```

### 3. 重置配置

```bash
# 备份现有配置
./install.sh config export

# 查看备份
ls -la ~/.joe_backups/
```

### 4. 报告问题

如果以上方法都无法解决：

1. 收集信息：
   ```bash
   ./install.sh doctor --json > /tmp/joe_diagnostic.json
   echo "TERM=$TERM" >> /tmp/joe_diagnostic.txt
   uname -a >> /tmp/joe_diagnostic.txt
   ```

2. 提交 Issue：
   - GitHub: https://github.com/IotaHydrae/joe/issues
   - 附上诊断信息
   - 描述复现步骤

---

## 调试技巧

### 启用详细输出

```bash
# Bash 调试模式
bash -x install.sh tools install node

# 或在脚本开头添加
set -x
```

### 测试特定功能

```bash
# 测试依赖解析
bash -c 'source scripts/lib/deps.sh; expand_components --ai gemini'

# 测试 TUI（需要交互终端）
bash scripts/ui/tui_tools.sh
```

### 检查环境

```bash
# 完整环境检查
env | grep -E "(TERM|PATH|SHELL|HOME|GHOSTTY)"

# Shell 类型
echo $SHELL
$SHELL --version
```

---

**更新日期**: 2025-10-20  
**适用版本**: Joe 2.0.0+
