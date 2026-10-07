# 项目规则

> 本文件由 [joe](https://github.com/IotaHydrae/joe) 提供，供 AI 编码代理读取。
> 放在项目根目录即可；`AGENTS.md` 同时被 Codex、MiMo Code 识别，
> Claude Code 通过同目录的 `CLAUDE.md` 导入本文件。

## 代码探索：优先用图谱工具，不要 grep 逐个文件找

本机已配置代码智能 MCP。**结构性提问必须走上表工具**，用 grep/glob 逐个文件翻找是低效且容易出错的。

| 需求 | 用哪个 MCP | 关键工具 |
|---|---|---|
| 谁调用了 X | codebase-memory-mcp | `trace_path(direction="inbound")` |
| X 调用了谁 | codebase-memory-mcp | `trace_path(direction="outbound")` |
| 完整调用上下文 | codebase-memory-mcp | `trace_path(direction="both")` |
| 按名字/模式找符号 | codebase-memory-mcp | `search_graph(name_pattern="...")` |
| 读某个符号的实现 | codebase-memory-mcp | `get_code_snippet(qualified_name="...")` |
| 文件骨架 | codebase-memory-mcp | `get_file_outline` |
| 复杂图查询 | codebase-memory-mcp | `query_graph`（Cypher） |
| 改动影响面 | codegraph | `codegraph_analyze_impact` |
| 循环依赖 | codegraph | `codegraph_find_circular_deps` |
| 死代码 / 未用导入 | codegraph | `codegraph_find_dead_imports` |
| 入口点 / 热点路径 | codegraph | `codegraph_find_entry_points` / `codegraph_find_hot_paths` |
| 精确符号定位 | serena | `find_symbol` / `get_symbols_overview` |
| 谁引用了这个符号 | serena | `find_referencing_symbols` |
| 符号级重构 | serena | `rename_symbol` / `replace_symbol_body` / `insert_after_symbol` |
| 第三方库最新用法 | context7 | `resolve-library-id` → `query-docs` |

### 首次使用：先建立索引

这三个工具是"能力型"的，**不索引/不激活就没有数据**：

- **codebase-memory-mcp** → `index_repository`
- **codegraph** → `codegraph_index_directory` 或 `codegraph_reindex_workspace`
- **serena** → `activate_project`

在项目里第一次工作时先做这一步。代码有较大改动后，重新索引再判断影响面。

### 明确禁止

- ❌ 为了"找某个函数在哪定义"去 read 十几个文件 —— 用 `find_symbol` / `search_graph`
- ❌ 凭函数名/变量名**猜测**行为 —— 用 `trace_path` / `find_referencing_symbols` 看实际关系
- ❌ 改接口前不做 caller/callee 分析
- ❌ 用内置 grep 搜索符号（图谱查询精确得多，且省 token）

### 例外：什么时候可以用普通工具

- 已知路径、只需看某个文件内容 → 直接 Read
- 纯文本/配置/文档检索 → grep 是合适的
- 图谱未覆盖的语言或未索引的目录 → 回退到 grep + Read

## 其他

- **需要长期记住的项目决策**：明确说"记住…"，代理会写入 memory MCP
- **批量文件操作**（按大小/时间筛选、整棵目录树）：filesystem MCP
- **Git 结构化查询**（暂存/未暂存 diff、历史）：git MCP，简单操作直接用 shell 更顺手
