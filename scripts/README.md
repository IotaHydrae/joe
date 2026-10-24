# scripts — 安装器与维护脚本

从仓库根目录运行 `./install.sh` 打开统一菜单，也可用子命令按需执行：

| 子命令 | 实现文件 |
|---|---|
| `shell` | `install_shell.sh` |
| `fonts` | `commands/fonts.sh` → `install_fonts.sh`；清单位于 `lib/fonts.sh` |
| `devtools` | `install_devtools.sh` |
| `mcp` | `install_mcp_servers.sh` |
| `skills` | `install_skills.sh` |
| `doctor` | `doctor.sh` |
| `update` | `update-all.sh` |
| `repair-ghostty` | `repair_ghostty.sh` |
| `configs` | `sync-configs.sh` |
| `quick-start` | `commands/quickstart.sh` (旧名 `bootstrap`) |

`tui_module.sh` 与 `lib_*.sh` 是同目录的共享库；`.config/`、`fonts/`、`.p10k.zsh`、`skills/`、`configs/` 等资产留在仓库根目录。脚本应分别解析脚本目录和仓库根目录，不能依赖调用者的当前工作目录。

```bash
./install.sh devtools --list
./install.sh skills --category kernel-dev --tui
./install.sh shell --dry-run
./install.sh fonts install --dry-run --all
```

开发工具、MCP 和 skills 默认不勾选任何项；非交互安装须明确安装项或 `--all`。日常软件（Brave 浏览器、ChatGPT Desktop、微信、QQ、Rime 输入法）不包含在 `--all` 或 `quick-start --yes` 中，可在主菜单第 2 项「日常软件」选择安装，或通过 `./install.sh tools install <id>` / `./install.sh devtools --<id>` 单独安装。

主菜单第 6 项「字体安装」或 `./install.sh fonts` 打开编号子菜单，包含 Fixedsys Excelsior（`fsex302`）和 JetBrains Mono（`jetbrains-mono`），支持查看状态、单项或全部安装、`b` 返回。`fonts list` / `fonts status` 只读；`fonts install <id...>`、`fonts install --all` 安装指定字体，带 `--dry-run` 可预览。字体和许可证随仓库提供；字体安装到 `~/.local/share/fonts`，无需网络或 sudo。JetBrains Mono 2.304 的四种基本字形位于 `fonts/jetbrains-mono/`；`shell` 默认安装 FSEX302。

`skills` / `skills --tui` 先显示「原有/本地技能」和「low-level-dev-skills」；后者进入 25 个分类的子菜单，再进入该分类的勾选列表。编号进入，`b`/`q` 返回上一级，安装后可继续选其他分类。`skills --category <name> --tui` 直接打开指定分类的勾选列表。
