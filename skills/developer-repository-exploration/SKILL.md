---
name: developer-repository-exploration
description: "Build a reliable engineering model of an unfamiliar repository BEFORE changing code: reconnaissance, build system, entry points, caller/callee/callback tracing, data and state flow, ownership and lifetime, configuration and external context. Use when starting work in an unknown codebase, onboarding to a project, or before modifying interfaces and initialization/teardown logic. Triggers on: explore repository, understand codebase, unfamiliar project, onboarding, build system, entry point, call graph, dependency closure, 陌生工程, 探索仓库, 理解代码库, 上手项目, 依赖分析."
---

# Developer Repository Exploration

## Purpose

在进入一个陌生工程、代码仓库或已有项目时，先建立足够可靠的工程模型，再开始修改代码。

本 Skill 解决以下常见问题：

* 只阅读当前文件或当前函数，就开始修改代码
* 根据函数名、变量名或经验猜测系统行为
* 不搜索 caller / callee / callback 就修改接口
* 不理解生命周期就修改初始化、退出或资源释放逻辑
* 不理解 build system 就添加文件、依赖或配置
* 不理解现有实现模式就重新发明一套实现
* 忽略 Device Tree、Kconfig、Makefile、配置文件等外部约束
* 只看到局部代码，却把局部理解当成整个系统事实
* 遇到不确定内容时继续“合理猜测”
* 一边修改代码，一边才逐渐发现原来的理解错误
* 最终形成“能运行，但架构和维护性很差”的代码

核心原则：

> **先理解，再修改。**
>
> **Evidence before assumption.**
>
> **Repository evidence before personal intuition.**

# 1. Core Rules

## 1.1 Do not code immediately

面对一个陌生 repository 时，默认进入：

```text
RECONNAISSANCE
    ↓
MODEL
    ↓
IMPLEMENT
    ↓
VERIFY
```

而不是：

```text
READ ONE FILE
    ↓
GUESS
    ↓
EDIT
    ↓
COMPILE
    ↓
PATCH
    ↓
GUESS AGAIN
```

在完成必要的工程侦察之前，不应修改生产代码。

---

## 1.2 Do not confuse local context with system context

当前文件中的代码只能说明局部行为。

不能因为看到：

```c
foo_init();
```

就假设：

* `foo_init()` 一定只被调用一次
* 调用者拥有资源
* 调用失败可以忽略
* 函数可以阻塞
* 函数可以睡眠
* 函数执行后状态一定发生变化

必须继续寻找：

* definition
* callers
* callees
* callbacks
* related structures
* initialization path
* teardown path
* error path
* tests
* configuration

---

## 1.3 Evidence before assumption

实现行为时，优先级：

```text
Actual repository code
        >
Repository tests
        >
Build/configuration
        >
Project documentation
        >
Authoritative external documentation
        >
General engineering knowledge
        >
Personal assumption
```

不能用经验替代 repository 中已经存在的事实。

例如不要因为：

```text
Linux driver 通常这样做
```

就直接修改驱动。

应该先搜索项目中已有的类似实现。

---

## 1.4 Unknown must remain unknown

如果某个行为尚未确认，应明确视为：

```text
UNKNOWN
```

而不是：

```text
PROBABLY ...
LIKELY ...
SHOULD ...
I ASSUME ...
```

正确流程：

```text
Unknown
  ↓
Search
  ↓
Read definition / caller / documentation / test
  ↓
Evidence
  ↓
Conclusion
```

如果仍然无法确认：

```text
Unknown
  ↓
Document uncertainty
  ↓
Choose the smallest safe change
```

---

## Detailed reference

完整内容见 [`references/full.md`](references/full.md) —— 需要具体步骤、示例、检查清单时再阅读。

<details>
<summary>参考文档目录</summary>

- 2. Repository Exploration Workflow
  - Phase 0 — Task Understanding
- 3. Phase 1 — Repository Reconnaissance
  - 3.1 Inspect repository structure
  - 3.2 Identify the build system
  - 3.3 Identify entry points
- 4. Phase 2 — Build the Repository Map
- 5. Phase 3 — Trace the Relevant Dependency Closure
  - 5.1 Caller analysis
  - 5.2 Callee analysis
  - 5.3 Callback analysis
- 6. Phase 4 — Understand Data and State Flow
  - 6.1 Data flow
  - 6.2 State flow
- 7. Phase 5 — Understand Ownership and Lifetime
- 8. Phase 6 — Understand Configuration and External Context
- 9. Phase 7 — Search for Existing Patterns
- 10. Phase 8 — Tests and Validation Infrastructure
- 11. Phase 9 — Create an Evidence-Based Implementation Model
- 12. Exploration Gate
- 13. Do Not Over-Explore
  - 13.1 Stop condition
- 14. Implementation Rules
  - 14.1 Make the smallest justified change
  - 14.2 Do not invent abstractions prematurely
  - 14.3 Preserve local conventions
- 15. Handling Contradictions
- 16. Handling New Information
- 17. Avoid Context-Driven Hallucination
- 18. Comments and Documentation
- 19. Exploration Output Should Be Compact
- 20. Anti-Patterns
- 21. Special Rules for Embedded/Linux Projects
- 22. Special Rules for Existing Mature Projects
- 23. Git History as Evidence
- 24. External Documentation
- 25. Final Verification
- 26. Compact Agent Protocol
- 27. Definition of Done

</details>
