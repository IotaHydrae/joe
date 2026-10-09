# scripts — 安装器与维护脚本

从仓库根目录运行 `./install.sh` 打开统一菜单，也可用子命令按需执行：

| 子命令 | 实现文件 |
|---|---|
| `shell` | `install_shell.sh` |
| `devtools` | `install_devtools.sh` |
| `mcp` | `install_mcp_servers.sh` |
| `skills` | `install_skills.sh` |
| `doctor` | `doctor.sh` |
| `update` | `update-all.sh` |
| `repair-ghostty` | `repair_ghostty.sh` |
| `configs` | `sync-configs.sh` |
| `bootstrap` | `bootstrap.sh` |

`tui_module.sh` 与 `lib_*.sh` 是同目录的共享库；`.config/`、`fonts/`、`.p10k.zsh`、`skills/`、`configs/` 等资产留在仓库根目录。脚本应分别解析脚本目录和仓库根目录，不能依赖调用者的当前工作目录。

```bash
./install.sh devtools --list
./install.sh skills --category kernel-dev --tui
./install.sh shell --dry-run
```

开发工具、MCP 和 skills 默认不勾选任何项；非交互安装须明确安装项或 `--all`。`bootstrap --yes` 是显式选择所有组件。

`skills` / `skills --tui` 先显示「原有/本地技能」和「low-level-dev-skills」；后者进入 25 个分类的子菜单，再进入该分类的勾选列表。编号进入，`b`/`q` 返回上一级，安装后可继续选其他分类。`skills --category <name> --tui` 直接打开指定分类的勾选列表。
