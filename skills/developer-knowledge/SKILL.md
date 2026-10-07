---
name: developer-knowledge
description: "Extract, distill and maintain a high-signal engineering knowledge base from real development work (solutions, decisions, debugging techniques, lessons learned). Use when writing or updating engineering notes, documenting a fix or technical decision, capturing a debugging finding, or organizing/curating a knowledge base. Triggers on: write knowledge note, document solution, capture lesson learned, record debugging finding, organize knowledge base, knowledge entry, 记录知识, 写文档, 总结经验, 知识库, 沉淀文档."
---

# Developer Knowledge Base

## Purpose

This skill defines how an Agent should extract, compress, organize, maintain, and retrieve reusable knowledge from software and embedded development work.

The goal is **not to archive conversations**.

The goal is to build a compact, high-signal, long-lived engineering knowledge base that helps a developer:

* remember solutions
* avoid repeating mistakes
* understand important technical decisions
* reproduce useful debugging techniques
* transfer experience between projects
* quickly answer similar future questions

The knowledge base must optimize for:

> **Signal density, retrieval speed, first-glance comprehension, and long-term reuse.**

# 1. Core Principle

## Knowledge Base ≠ Conversation Archive

Never treat the knowledge base as a transcript of the development process.

Do not automatically preserve:

* every command executed
* every failed attempt
* every intermediate hypothesis
* long terminal output
* repetitive explanations
* obvious background knowledge
* temporary state
* irrelevant implementation details
* the entire reasoning process

Instead preserve:

```text
Problem
    ↓
Important observation
    ↓
Root cause / useful insight
    ↓
Solution
    ↓
Reusable lesson
```

The knowledge base stores the **distilled result**, not the complete journey.

---

## Detailed reference

完整内容见 [`references/full.md`](references/full.md) —— 需要具体步骤、示例、检查清单时再阅读。

<details>
<summary>参考文档目录</summary>

- 2. First-Screen Rule
- 3. Information Budget
- 4. One Document, One Primary Question
- 5. Knowledge Value Classification
  - A — Durable Knowledge
  - B — Project Knowledge
  - C — Debugging Trace
  - D — Ephemeral Information
- 6. Distill Before Writing
- 7. Never Confuse Research With Knowledge
- 8. Conclusions Come Before Background
- 9. Separate Facts, Observations, and Hypotheses
- 10. Evidence Should Be Compact
- 11. Failed Attempts
- 12. Avoid Reasoning Transcripts
- 13. Command Output Policy
- 14. Code Examples
- 15. Project Knowledge vs General Knowledge
- 16. Prefer Atomic Knowledge
- 17. Avoid Duplicate Knowledge
- 18. Canonical Knowledge
- 19. Knowledge Compression Pass
- 20. 50% Compression Test
- 21. First 20 Lines Rule
- 22. TL;DR Requirements
- 23. Recommended Document Template
- 24. Simple Problem Template
- 25. Troubleshooting Template
- 26. Architecture / Design Template
- 27. Experimental Knowledge
- 28. Hardware Measurements
- 29. Version-Sensitive Knowledge
- 30. Time-Sensitive Information
- 31. Secrets and Sensitive Data
- 32. Desensitization
- 33. Naming
- 34. Titles
- 35. Tags
- 36. Links
- 37. References
- 38. Source Code as Evidence
- 39. Retrieval-Oriented Writing
- 40. Error Codes Are Valuable Anchors
- 41. Do Not Over-Explain Obvious Concepts
- 42. Deep Explanations
- 43. Split Large Documents
- 44. Avoid Recursive Knowledge Growth
- 45. Prevent Knowledge Inflation
- 46. Prefer Replacement Over Append
- 47. Knowledge vs Journal
- 48. When to Create a Knowledge Entry
- 49. When NOT to Create a Knowledge Entry
- 50. Knowledge Quality Test
- 51. Knowledge Quality Levels
  - Level 0 — Raw Notes
  - Level 1 — Organized Notes
  - Level 2 — Distilled Knowledge
  - Level 3 — High-Value Knowledge
- 52. Agent Output Strategy
- 53. Default Writing Behavior
- 54. User-Requested Deep Documentation
- 55. Explicit "Detailed" Mode
- 56. Document Length Escalation
- 57. Example: Bad Knowledge Entry
- 58. Example: Good Knowledge Entry
- 59. The "Would I Search This?" Test
- 60. The "Future Me" Test
- 61. Final Rule

</details>
