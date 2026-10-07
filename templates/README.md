# templates — 放进项目的规则文件

让 AI 代理**自动用上本机的 MCP**，而不是每次都要你提醒。

## 文件怎么选

`AGENTS.md` 是各代理的公共交集：

| 代理 | 读取 `AGENTS.md` | 说明 |
|---|---|---|
| **Codex** | ✅ 原生 | — |
| **MiMo Code** | ✅ 原生（优先） | 无 `AGENTS.md` 时才回退 `CLAUDE.md` |
| **Claude Code** | ⚠️ 原生支持，**但项目里有 `CLAUDE.md` 时默认忽略 `AGENTS.md`** | 见下 |

> 依据：Claude Code 2.1.292 二进制内的说明 —
> *"AGENTS.md as project instructions: by default loaded where the project has no CLAUDE.md;
> by its instructionFiles option, loaded beside CLAUDE.md, left out, or with the project instructions dropped"*

### 因此按情况选

**情况 A：项目里没有 `CLAUDE.md`** → 只放 `AGENTS.md` 就够了

```bash
cp ~/iotahydrae/joe/templates/AGENTS.md .
```

**情况 B：项目里已经有 `CLAUDE.md`**（Claude Code 项目常见）→ 放 `AGENTS.md`，
并在你**已有的** `CLAUDE.md` 末尾加一行导入（**不要覆盖**原文件）：

```markdown
@AGENTS.md
```

**情况 C：想省事、统一处理** → 两个都拷

```bash
cp ~/iotahydrae/joe/templates/AGENTS.md .
cp ~/iotahydrae/joe/templates/CLAUDE.md .   # 内容是 @AGENTS.md
```

> `CLAUDE.md` 里只有一行 `@AGENTS.md`，规则本身**只维护 `AGENTS.md` 一份**，不会漂移。

## 全局（所有项目生效）

不想每个项目都放，可以放到全局位置：

```bash
# Claude Code
cp AGENTS.md ~/.claude/CLAUDE.md

# MiMo Code
mkdir -p ~/.config/mimocode && cp AGENTS.md ~/.config/mimocode/AGENTS.md

# Codex
cp AGENTS.md ~/.codex/AGENTS.md
```

> 优先级：项目内文件 > 全局文件。项目里放了就以项目的为准。

## 按需裁剪

模板是通用的。如果你的项目只用到部分能力，删掉无关行即可——**规则越短，代理越容易遵守**。

例如纯文档仓库，可以只留最后"其他"一节。
