# configs — 本机配置备份（自动生成）

由 `../install.sh configs export` 生成，**已做脱敏**（API key / token / 密码 / Bearer 等被替换为 `***REDACTED***`）。

| 文件 | 来源 | 说明 |
|---|---|---|
| `zshrc` | `~/.zshrc` | shell 环境 |
| `gitconfig` | `~/.gitconfig` | git 身份与别名 |
| `claude-mcp.json` | `~/.claude.json` | **仅** `mcpServers`；已丢弃 userID/machineID/projects |
| `codex-config.toml` | `~/.codex/config.toml` | Codex CLI 配置 |
| `mimocode.jsonc` | `~/.config/mimocode/mimocode.jsonc` | MiMo Code 配置 |
| `zed-settings.json` | `~/.config/zed/settings.json` | Zed 设置 |
| `vscode-mcp.json` | `~/.config/Code/User/mcp.json` | VS Code MCP 配置 |

## 恢复

```bash
./install.sh configs import     # 原文件会备份为 .bak.<时间戳>
```

## 提交前请复核

```bash
git diff configs/
```

> 脱敏是**尽力而为**的兜底，不保证覆盖所有密钥形式。提交前请自行确认没有敏感信息。
