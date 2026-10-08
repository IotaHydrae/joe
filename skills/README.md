# joe skills — 代理技能库

存放可复用的 **Agent Skills**，通过 `../install_skills.sh` 安装到各 AI 代理。

## 第三方技能

`engineering-embedded-linux-driver-engineer` 提供嵌入式 Linux 内核驱动与 BSP 开发指导，包括设备树、Platform/I2C/SPI/USB、DMA/中断和 Yocto/Buildroot。来自 [clowlove/hermes-house](https://www.skills.sh/clowlove/hermes-house/engineering-embedded-linux-driver-engineer)，保留上游 `SKILL.md`、`skill.json`，随附 MIT `LICENSE`；确切版本见 [SOURCE.md](engineering-embedded-linux-driver-engineer/SOURCE.md)。

在仓库根目录按需安装：

```bash
./install_skills.sh engineering-embedded-linux-driver-engineer
```

也可以运行 `./install_skills.sh --tui` 后勾选；默认不勾选任何技能。

## 目录结构

```
skills/
├── README.md                 # 本文件
└── <skill-name>/
    └── SKILL.md              # 技能定义 (必需)
```

## SKILL.md 格式

必须包含 YAML frontmatter，其中 `name` 与 `description` 均为**必填**：

```markdown
---
name: my-skill
description: 一句话说明何时该用我 (代理先只看到这段, 要具体)
---

# 标题

技能正文: 步骤、判据、示例、注意事项。
```

> `description` 是代理决定是否加载技能的唯一信号，请写清**触发场景**（例如"当用户要求发布版本时"）。
> 可选字段 `hidden: true` 会让技能加载但不显示在列表中。
> **文件名必须全大写** `SKILL.md`，技能名取自 frontmatter 的 `name`（不是文件夹名）。

## 安装位置

`install_skills.sh` 会把技能复制到以下目录（按已安装的代理）：

| 目录 | 归属 |
|---|---|
| `~/.agents/skills/` | 通用（跨工具约定） |
| `~/.claude/skills/` | Claude Code |
| `~/.codex/skills/` | Codex CLI |
| `~/.config/mimocode/skills/` | MiMo Code（原生路径） |
| `~/.copilot/skills/` | GitHub Copilot（目录存在时） |

> MiMo Code 还会扫描 `~/.claude`、`~/.agents`、`~/.codex`、`~/.opencode` 下的 `skills/**/SKILL.md`，
> 因此安装到这些目录即可同时被多个代理发现。

## 添加新技能

```bash
mkdir -p skills/<skill-name>
$EDITOR skills/<skill-name>/SKILL.md
../install_skills.sh --list        # 确认已被识别
../install_skills.sh --tui          # 勾选安装
```

脚本是**幂等**的：内容有变化的技能会更新，未变化的跳过。
