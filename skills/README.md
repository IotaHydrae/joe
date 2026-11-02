# joe skills — 代理技能库

存放可复用的 **Agent Skills**，通过 `../install.sh skills` 安装到各 AI 代理。

## 第三方技能

`engineering-embedded-linux-driver-engineer` 提供嵌入式 Linux 内核驱动与 BSP 开发指导，包括设备树、Platform/I2C/SPI/USB、DMA/中断和 Yocto/Buildroot。来自 [clowlove/hermes-house](https://www.skills.sh/clowlove/hermes-house/engineering-embedded-linux-driver-engineer)，保留上游 `SKILL.md`、`skill.json`，随附 MIT `LICENSE`；确切版本见 [SOURCE.md](engineering-embedded-linux-driver-engineer/SOURCE.md)。

在仓库根目录按需安装：

```bash
./install.sh skills --project <项目目录> engineering-embedded-linux-driver-engineer
```

也可以运行 `./install.sh skills --project <项目目录> --tui`，进入「原有/本地技能」后勾选；默认不勾选任何技能。
技能为项目级安装，必须显式指定 `--project <目录>`。

### low-level-dev-skills 技能集

来自 [mohitmishra786/low-level-dev-skills](https://github.com/mohitmishra786/low-level-dev-skills) 的 **142 个子技能、25 个分类**已分别集成，完整分类清单与来源版本见 [low-level-dev-skills.md](low-level-dev-skills.md)。每个技能保留参考文件，附带 MIT 许可证及 `SOURCE.md`。上游 `skills/<category>/<name>` 跨技能引用已统一为 joe 的 `skills/<name>`。

从仓库根目录按分类浏览或按技能名安装：

```bash
./install.sh skills --project <项目目录>              # low-level-dev-skills → 分类 → 按需勾选
./install.sh skills --categories
./install.sh skills --project <项目目录> --category kernel-dev --category kernel --tui
./install.sh skills --project <项目目录> device-tree bus-drivers-i2c-spi gdb cross-gcc
./install.sh skills --project <项目目录> --category kernel-dev --all  # 显式安装该分类全部技能
```

默认先选技能组，再进入 low-level-dev-skills 的分类子菜单，142 个技能按 25 个分类展示。编号进入，`b`/`q` 返回上一级；安装后或退出勾选列表后返回当前菜单。指定 `--category` 则直接打开过滤后的勾选列表，完成后退出安装器。

分类元数据在 `categories.tsv`，未列入该表的技能归入 `local`。重复 `--category` 取并集；与 `--list`、`--tui`、`--all` 和技能名组合时只作用于这些分类。默认不勾选任何技能，相关技能与系统工具也不会自动安装。

## 目录结构

```
skills/
├── README.md                 # 本文件
├── categories.tsv            # 可选分类元数据 (技能名 TAB 分类名)
├── low-level-dev-skills.md    # 第三方技能集目录与来源
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

技能是**项目级**安装：必须用 `--project <目录>` 指定目标项目（`<project>` 替换为你的项目根路径），
把技能复制到以下目录（按已安装的代理）：

| 目录 | 归属 |
|---|---|
| `<project>/.agents/skills/` | 通用实体副本（Gemini / OpenCode / MiMo 自动发现） |
| `<project>/.claude/skills/` | Claude Code（符号链接） |
| `<project>/.codex/skills/` | Codex CLI（符号链接） |
| `<project>/.grok/skills/` | Grok Build（符号链接） |
| `<project>/.copilot/skills/` | GitHub Copilot（符号链接，目录存在时） |

> Gemini / OpenCode / MiMo 会从项目 `.agents/skills/` 自动发现技能，无需符号链接。
> 不再写入全局 `~/.agents/skills`，避免代理在每轮对话都扫描全部技能、浪费 token。

## 添加新技能

```bash
mkdir -p skills/<skill-name>
$EDITOR skills/<skill-name>/SKILL.md
../install.sh skills categories                  # 确认技能被识别
../install.sh skills --project <项目目录> --tui    # 勾选安装到指定项目
```

脚本是**幂等**的：内容有变化的技能会更新，未变化的跳过。

为技能指定分类时，在 `categories.tsv` 中追加一行 `技能名<TAB>分类名`；不用修改安装器的技能清单。TUI 支持 `PgUp/PgDn` 翻页和 `Home/End` 到首尾。
