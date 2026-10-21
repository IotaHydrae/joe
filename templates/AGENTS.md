# AI 代理项目规则模板

> 本文件供 AI 编码代理（Claude Code、Codex、MiMo Code 等）读取。
> 将其放置在项目根目录并根据实际情况修改；`AGENTS.md` 被多数代理识别，
> Claude Code 通常通过 `CLAUDE.md` 导入本文件。

## 代码探索策略

### 优先级原则

当环境已配置代码智能工具（MCP 服务）时，优先使用图谱查询而非盲目遍历文件。

**前提检查**：使用前先确认以下 MCP 服务是否可用（通过 `ListMcpResourcesTool` 或对应工具调用）：
- `codebase-memory-mcp` — 代码图谱与语义分析
- `codegraph` — 依赖关系与影响面分析  
- `serena` — LSP 驱动的精确符号操作
- `context7` — 第三方库文档查询

### 工具选择速查表

仅在对应 MCP 服务**已配置且可用**时使用以下工具：

| 任务类型 | MCP 服务 | 关键工具 |
|---------|---------|----------|
| 查找调用方（谁用了 X） | codebase-memory-mcp | `trace_path(direction="inbound")` |
| 查找被调用方（X 用了谁） | codebase-memory-mcp | `trace_path(direction="outbound")` |
| 双向调用链 | codebase-memory-mcp | `trace_path(direction="both")` |
| 按名称/模式找符号 | codebase-memory-mcp | `search_graph(name_pattern="...")` |
| 读取符号实现 | codebase-memory-mcp | `get_code_snippet(qualified_name="...")` |
| 文件结构大纲 | codebase-memory-mcp | `get_file_outline` |
| 复杂图谱查询 | codebase-memory-mcp | `query_graph`（Cypher 语法） |
| 改动影响分析 | codegraph | `codegraph_analyze_impact` |
| 检测循环依赖 | codegraph | `codegraph_find_circular_deps` |
| 查找死代码/未用导入 | codegraph | `codegraph_find_dead_imports` |
| 查找入口点/热点路径 | codegraph | `codegraph_find_entry_points` / `codegraph_find_hot_paths` |
| 精确符号定位 | serena | `find_symbol` / `get_symbols_overview` |
| 查找符号引用 | serena | `find_referencing_symbols` |
| 符号级重构 | serena | `rename_symbol` / `replace_symbol_body` / `insert_after_symbol` |
| 查询库文档（最新 API） | context7 | `resolve-library-id` → `query-docs` |

### 首次使用：索引建立

以下工具**需要先索引才能使用**，首次工作时必须执行相应初始化：

- **codebase-memory-mcp** → `index_repository(repo_path=".")`
- **codegraph** → `codegraph_index_directory` 或 `codegraph_reindex_workspace`
- **serena** → `initial_instructions` 后按提示激活项目

代码有显著改动后（新增/删除模块、重构），重新索引以确保分析准确。

### 行为约束

**明确禁止**（当图谱工具可用时）：
- ❌ 为定位符号位置而读取大量文件 → 用 `find_symbol` / `search_graph`
- ❌ 仅凭名称猜测行为而不查关系 → 用 `trace_path` / `find_referencing_symbols`
- ❌ 修改接口前不分析调用方 → 用 `trace_path` 或 `find_referencing_symbols`
- ❌ 用 grep 搜索符号定义 → 图谱查询更精确且节省 token

**允许回退到普通工具的情况**：
- 已知文件路径，仅需读取内容 → 直接 `read_file`
- 搜索纯文本/配置/文档内容 → `grep` / `web_search` 合适
- 图谱未覆盖的语言或未索引目录 → `grep` + `read_file`
- MCP 服务不可用或索引失败 → 降级到传统工具链

## 项目特定配置示例

以下部分根据项目实际情况填写，删除不适用的内容。

### 构建与测试命令

```bash
# 构建
npm run build          # 或 make / cargo build / mvn package

# 测试
npm test              # 或 pytest / cargo test / mvn test

# 代码检查
npm run lint          # 或 ruff check / cargo clippy
```

### 目录结构约定

```
src/          - 源代码
tests/        - 测试文件
docs/         - 文档
scripts/      - 工具脚本
```

### 编码风格

- 缩进：4 空格 / 2 空格 / Tab
- 命名：snake_case / camelCase / PascalCase
- 注释：函数必须有文档注释 / 仅复杂逻辑需注释
- 导入顺序：标准库 → 第三方 → 本地模块

### 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：
- `feat:` 新功能
- `fix:` 修复 bug  
- `docs:` 仅文档修改
- `refactor:` 重构（不改变外部行为）
- `test:` 测试相关
- `chore:` 构建/工具配置

### 安全约束

- ❌ 禁止硬编码密钥/令牌 → 使用环境变量
- ❌ 禁止提交 `.env` 文件 → 保持 `.gitignore` 生效
- ❌ 数据库迁移需人工审核 → 先生成、展示、再执行
- ⚠️  外部 API 调用需幂等性检查

### 依赖管理

- 新增依赖前检查许可证兼容性
- 优先使用项目已有的库，避免重复引入
- 更新依赖后运行完整测试套件

---

## 使用指南

### 对于项目维护者

1. 复制本模板到项目根目录并重命名为 `AGENTS.md`
2. 删除"项目特定配置示例"标题，保留实际配置内容
3. 根据项目技术栈修改构建命令、目录结构等
4. 如果使用 Claude Code，在 `CLAUDE.md` 中添加：
   ```markdown
   Follow the project rules in AGENTS.md.
   ```

### 对于 AI 代理

优先级顺序：
1. 检查是否有 MCP 工具可用 → 使用图谱查询
2. 遵循项目特定配置（构建/测试命令、编码风格）
3. 不确定时**先读取相关代码**再行动，不要猜测
4. 重大改动前分析影响面，小改动后运行测试验证

---

**模板版本**：v1.0  
**适用于**：通用软件项目（可根据实际情况裁剪）
