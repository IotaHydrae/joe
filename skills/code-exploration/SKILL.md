---
name: code-exploration
description: 在本机用 MCP 工具高效探索代码库（符号检索、调用链、影响面、文档查询），替代逐个读文件。当需要理解代码结构、查找符号/调用者、评估改动影响、查第三方库文档时使用。Triggers on: explore codebase, find symbol, who calls, call chain, impact analysis, understand architecture, look up docs, 代码结构, 调用链, 影响面, 查文档.
---

# 用 MCP 工具探索代码

本机配置了多个代码智能 MCP。**结构化查询通常省 90%+ token**，别用 grep + 逐个读文件去找符号。

## 先做两个判断，再选工具

### 判断 1：这个语言的 LSP 装了吗？→ 决定能不能用 serena

`serena` 基于语言服务器（LSP），**LSP 缺失时是硬失败，不会降级**。例如 Rust 项目未装 `rust-analyzer` 时会直接报错。

```bash
# 快速检查
command -v rust-analyzer gopls clangd pyright-langserver typescript-language-server 2>/dev/null
ls ~/.serena/language_servers/static/ 2>/dev/null   # serena 自动下载过的
```

- **有 LSP** → serena 可用
- **没有** → 不要选 serena，改用 `codebase-memory-mcp` 或 `codegraph`

> serena 会**按语言自动下载** LSP，体积差别很大：clangd ≈ 281M、bash ≈ 33M。
> 首次在某语言上使用会慢（C 项目实测首次 `find_symbol` 56s），这是下载 + 冷启动，之后 0.9s。

### 判断 2：仓库多大？→ 决定选 cmm 还是 codegraph

| 仓库规模 | 查询延迟表现 | 推荐 |
|---|---|---|
| 小（<200 文件） | 都很快 | 看语言：有 LSP 用 serena（符号最准） |
| 中（200–5000） | 差异明显 | `codebase-memory-mcp`（延迟恒定） |
| 大（>5000） | cmm 不随规模增长 | **`codebase-memory-mcp`** |

**实测关键差异：`codebase-memory-mcp` 的查询延迟是恒定的**（46 文件 → 1896 文件，始终 0.05s），
而 `codegraph`（0.35→0.85s）和 `serena`（0.2→0.9s）**随代码量增长**。

## 选型矩阵

| 需求 | 用哪个 | 关键工具 |
|---|---|---|
| 谁调用了 X / 调用链 | `codebase-memory-mcp` | `trace_path(direction="inbound"/"outbound"/"both")` |
| 按名字找符号（大仓库） | `codebase-memory-mcp` | `search_graph(name_pattern=...)` |
| 读某符号的实现 | `codebase-memory-mcp` | `get_code_snippet(qualified_name=...)` |
| 改动影响面 / 爆炸半径 | `codegraph` | `codegraph_analyze_impact` |
| 循环依赖 / 死代码 | `codegraph` | `codegraph_find_circular_deps` / `find_dead_imports` |
| **语义搜索**（"找处理重试的代码"） | `codegraph` | `codegraph_symbol_search`（fastembed 向量检索） |
| 精确符号定位（小-中项目） | `serena` | `find_symbol` / `get_symbols_overview` |
| 谁引用了这个符号 | `serena` | `find_referencing_symbols` |
| **符号级重构**（重命名、精确插入） | `serena` | `rename_symbol` / `insert_after_symbol` |
| 第三方库最新用法 | `context7` | `resolve-library-id` → `query-docs` |

> 只用 `serena` 做**符号级编辑**是它不可替代的地方（LSP 保证准确）；
> 纯查询在大仓库上优先 `codebase-memory-mcp`。

## 一次性成本（心里有数即可）

| MCP | 首次成本 | 之后 |
|---|---|---|
| `codebase-memory-mcp` | 无 | 每项目 452K–16M |
| `codegraph` | 约 128M 嵌入模型 | 每项目约 12M |
| `serena` | 每语言 33–281M LSP | 不落盘 |

## 典型流程

1. **确认索引状态**：`codebase-memory-mcp` 的 `list_projects` / `index_status`；未索引先 `index_repository`
2. **定位符号**：`search_graph(name_pattern=...)`，不要全文 grep
3. **理清关系**：`trace_path` 看调用方向
4. **看实现**：`get_code_snippet` 按需取片段，别整文件读
5. **评估改动**：`detect_changes()` 或 `codegraph_analyze_impact`
6. **查文档**：第三方库用 `context7`

## 注意

- **索引会过期**：改完代码用 `codegraph_reindex_workspace` / `detect_changes` 刷新
- **别重复劳动**：图谱查到的事实不必再 grep 验证
- **退化路径**：语言无 LSP、或仓库未索引时，老实回退到 grep + Read，别硬调
