---
name: code-exploration
description: 在本机用 MCP 工具高效探索代码库（符号检索、调用链、影响面、文档查询），替代逐个读文件。当需要理解代码结构、查找符号/调用者、评估改动影响、查第三方库文档时使用。Triggers on: explore codebase, find symbol, who calls, call chain, impact analysis, understand architecture, look up docs, 代码结构, 调用链, 影响面, 查文档.
---

# 用 MCP 工具探索代码

本机已配置多个代码智能 MCP。**优先用它们，而不是 grep + 逐个读文件**——结构化查询通常省 90%+ token。

## 工具选择

| 需求 | 首选 | 备选 |
|---|---|---|
| 代码结构 / 调用链 / 影响面 | `codebase-memory-mcp` | `codegraph` |
| 按符号名检索、读符号源码 | `serena`（`find_symbol` / `get_symbols_overview`） | `codebase-memory-mcp` |
| 第三方库用法 / 框架文档 | `context7` | WebFetch |
| 跨语言依赖、PR 影响范围、死代码 | `codegraph` | `codebase-memory-mcp` |
| 跨会话记住项目决策 | `memory` | `serena` 的 memory 工具 |
| 精确读写文件 | `filesystem` | 内置 Read/Write |

## 典型流程

1. **先确认是否已索引**：`codebase-memory-mcp` 的 `list_projects`；未索引则让它索引当前仓库
2. **结构性定位**：`search_graph` / `search_graph(name_pattern=...)` 找符号，而非全文 grep
3. **搞清关系**：`trace_path(direction="inbound")` 查谁调用；`"outbound"` 查调用谁
4. **看实现**：`get_code_snippet(qualified_name=...)` 按需取片段，避免整文件读入
5. **评估改动**：`detect_changes()` / codegraph 的 `analyze_impact` 判断爆炸半径
6. **查文档**：涉及第三方库时用 `context7` 的 `resolve-library-id` + `query-docs`

## Serena 用法要点

Serena 是**按项目**工作的（`--project-from-cwd`）。首次在某项目使用时先激活：

- `activate_project` 指定项目，或让它在当前目录初始化
- `get_symbols_overview` 拿文件骨架 → `find_symbol` 定位 → `insert_after_symbol` 等做符号级编辑
- 编辑优先用 Serena 的符号级工具而非整文件改写，减少误伤

## 注意

- **索引会过期**：改完代码后用 `reindex_workspace` / `detect_changes` 刷新
- **首次调用较慢**：CodeGraph 建图、Serena 下载依赖，属正常
- **别重复劳动**：已用图谱查到的事实，不必再 grep 验证
