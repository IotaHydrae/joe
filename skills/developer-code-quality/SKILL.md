---
name: developer-code-quality
description: "Rules for writing and reviewing source code for long-term human maintainability: local comprehension, obvious control flow, naming, function size, abstraction and duplication trade-offs. Use when writing, modifying, reviewing or refactoring code in any language (C/C++, Rust, Python, Go, JS/TS, shell, kernel, firmware). Triggers on: code review, refactor, naming, readability, maintainability, clean up code, 代码审查, 重构, 命名, 可读性, 代码质量, 可维护性."
---

# Developer Code Quality

## Purpose

Write code that is not only correct and runnable, but also easy for another developer to understand, debug, modify, and maintain.

The Agent must treat:

> **"It works" as an intermediate state, not the final state.**

---

# 1. Core Priorities

Optimize code in this order:

1. Correctness
2. Safety and resource lifetime
3. Clear control flow
4. Maintainability
5. Testability
6. Simplicity
7. Performance when justified

Do not optimize for:

* minimum line count
* maximum abstraction
* maximum comment coverage
* cleverness
* genericity for its own sake

Prefer:

```text
explicit > implicit
simple > clever
meaningful names > explanatory comments
local reasoning > global reasoning
focused changes > broad rewrites
justified abstraction > speculative abstraction
```

---

# 2. Code Must Be Locally Understandable

A developer should be able to open a function and quickly understand:

* what it does
* its important inputs and outputs
* the main execution path
* important state changes
* error handling
* unusual constraints

Avoid code that requires reconstructing the entire repository before a small function can be understood.

Prefer:

```c
validate_input();
prepare_transfer();
submit_transfer();
handle_result();
```

over a large function mixing unrelated responsibilities.

---

# 3. Control Flow and Function Design

## Keep functions cohesive

A function should have one coherent responsibility.

Split a function when it contains several independent phases, algorithms, or responsibilities.

Good:

```c
probe()
{
    ret = init_hardware();
    if (ret)
        return ret;

    ret = init_protocol();
    if (ret)
        return ret;

    return init_buffers();
}
```

Avoid giant functions containing hardware setup, protocol parsing, allocation, retry logic, logging, and cleanup all at once.

## Prefer simple control flow

Use:

* guard clauses
* early returns
* explicit branches
* shallow nesting
* meaningful helper functions

Avoid:

* deeply nested conditionals
* deeply nested ternaries
* clever one-line expressions
* hidden side effects

If a condition expresses a meaningful concept, consider naming it:

```c
if (device_can_start(dev))
    start_device(dev);
```

instead of embedding a long boolean expression.

## Do not over-split

A helper is useful when its name makes the caller easier to understand.

Do not turn every trivial operation into a function merely to reduce line count.

---

# 4. Names, Types, and Data Flow

Code should communicate meaning through structure.

Prefer:

```c
bool connected;
enum device_state state;
int retry_count;
```

over ambiguous values such as:

```c
int flag;
int state;
int value;
int tmp;
```

when the more precise representation is practical.

## Naming rules

Use names that communicate:

* purpose
* lifecycle
* state
* ownership where relevant

Use established project abbreviations where appropriate.

Do not make names unnecessarily verbose.

## Make state explicit

If several booleans represent mutually exclusive states, consider an enum/state machine.

If ownership or lifetime matters, make it visible through:

* types
* function boundaries
* naming
* explicit cleanup

Avoid unnecessary global state and hidden mutation.

Prefer explicit data flow:

```c
frame = capture_frame(dev);
processed = process_frame(frame);
submit_frame(display, processed);
```

over hidden mutation of global buffers.

## Keep scope narrow

Variables, helpers, constants, and implementation details should have the smallest reasonable scope.

Do not reuse one variable for multiple unrelated meanings.

Declare variables close to where they are used.

---

# 5. Abstraction and Complexity

## Every abstraction must earn its complexity

Introduce an abstraction when it provides a concrete benefit, such as:

* removing meaningful duplication
* isolating a subsystem
* enforcing an invariant
* providing a stable interface
* supporting real substitution
* simplifying callers

Do not introduce factories, strategies, generic frameworks, wrappers, or layers merely because they appear architecturally elegant.

## Avoid premature generalization

For one concrete use case, prefer a clear concrete implementation unless there is evidence that generalization is needed.

Small duplication can be better than a complicated abstraction.

## Watch complexity signals

Review the design when you see:

* very long functions
* deep nesting
* many parameters
* many boolean parameters
* repeated conditionals
* large context structures
* excessive global state
* duplicated cleanup
* unclear ownership
* unclear state transitions
* large switch statements

These are signals, not automatic violations.

The goal is to reduce unnecessary cognitive load, not to satisfy arbitrary numeric thresholds.

---

# 6. Error Handling, Resources, and Concurrency

Important lifecycle and failure behavior must be obvious.

A reviewer should be able to answer:

```text
What was acquired?
Who owns it?
Where is it released?
What happens if step N fails?
What state is the object in?
```

Use the project's established error-handling style.

For C/kernel code, clear `goto` cleanup paths are acceptable and often preferable when they make ownership obvious.

Do not replace clear cleanup code merely to avoid `goto`.

## Concurrency

Make synchronization and execution context visible.

Important questions should be answerable from the code:

* What lock protects this data?
* Who owns the resource?
* Can this execute concurrently?
* Can this context sleep?
* What happens during cancellation?
* What happens after a callback?

For asynchronous systems, make lifecycle transitions explicit:

```text
submit → pending → callback → complete
```

Avoid callback chains and hidden shared state that make lifecycle reasoning difficult.

---

# 7. Comments and Documentation

## Comments explain WHY, not WHAT

Do not write comments that merely restate code:

```c
/* Increment retry count */
retry_count++;
```

Useful comments explain things that cannot be made obvious through code:

* hardware quirks
* protocol requirements
* non-obvious invariants
* synchronization constraints
* compatibility requirements
* reasons for surprising implementation choices

Example:

```c
/*
 * The controller requires 10 ms after reset before the first command.
 * Sending it earlier intermittently fails on revision B hardware.
 */
sleep_ms(RESET_SETTLE_MS);
```

## Never use comments as a substitute for structure

If code needs a huge comment to explain its control flow, first consider:

1. better names
2. simpler control flow
3. smaller functions
4. explicit state
5. better data structures

Only then add a concise comment if necessary.

## Do not dump context into source files

Do not put the Agent's reasoning, investigation history, conversation context, or a mini knowledge base above a small piece of code.

Avoid:

```text
200 lines of explanation
        ↓
5 lines of code
```

Prefer:

```text
small amount of rationale
        ↓
clear code
```

Comments must be concise, local, and actionable.

---

# 8. Project-Specific and Hardware-Specific Code

Follow existing project conventions before introducing new patterns.

Do not mix a feature change with unrelated:

* formatting
* renaming
* architecture rewrites
* cleanup
* dependency changes

unless required.

Keep diffs focused.

## Hardware and low-level code

Distinguish clearly between:

```text
specification
observed behavior
measurement
derived value
workaround
```

Do not turn a measured value into a "required" constant without evidence.

Keep hardware quirks localized rather than scattering revision checks throughout the codebase.

Use meaningful constants for protocol- or hardware-defined values.

---

# 9. Finalization Protocol

The Agent MUST NOT stop immediately after the implementation works.

Before delivering code, perform these passes.

## Pass 1 — Correctness

Check:

```text
[ ] Compiles / parses
[ ] Tests pass where applicable
[ ] Error paths are handled
[ ] Resource lifetimes are correct
[ ] Concurrency assumptions are valid
[ ] Hardware / protocol constraints are respected
```

## Pass 2 — Readability

Check:

```text
[ ] Main path is obvious
[ ] Names communicate meaning
[ ] Control flow is simple
[ ] Functions are cohesive
[ ] Important state is explicit
[ ] Ownership is understandable
```

## Pass 3 — Simplification

Ask:

```text
Can this be simpler?
Can this function be smaller?
Can this condition be clearer?
Can this abstraction be removed?
Can this variable be renamed?
Can this comment be deleted?
Can hidden state become explicit?
```

Prefer simplification over adding more explanation.

## Pass 4 — Diff Review

Remove:

* debug code
* dead code
* unused variables
* temporary comments
* accidental formatting changes
* unrelated refactoring
* speculative abstractions

The final diff should have a clear reason for every meaningful change.

---

# Final Rule

Before delivering code, ask:

> **"If I did not write this code, could I understand it and safely modify it six months from now?"**

If the answer is no, improve the structure before adding more comments.

The final implementation should make the important behavior obvious without requiring the reader to reconstruct the Agent's entire context window.

## Detailed reference

完整内容见 [`references/full.md`](references/full.md) —— 需要具体步骤、示例、检查清单时再阅读。

<details>
<summary>参考文档目录</summary>

- 2. Two-Phase Implementation
- 3. The 10-Second Code Test
- 4. Local Comprehension
- 5. Make Control Flow Obvious
- 6. Avoid Excessive Nesting
- 7. Main Path Should Be Visually Obvious
- 8. Function Size
- 9. The Single-Responsibility Test
- 10. Function Extraction
- 11. Do Not Over-Split
- 12. Names Are Documentation
- 13. Avoid Ambiguous Names
- 14. Boolean Names
- 15. Avoid Generic `state`
- 16. Use Types to Encode Meaning
- 17. Avoid Magic Numbers
- 18. Constants Should Represent Concepts
- 19. Avoid Excessive Abstraction
- 20. Abstraction Must Earn Its Complexity
- 21. Avoid Premature Generalization
- 22. Duplication vs Abstraction
- 23. Avoid Cleverness
- 24. One Concept Per Statement
- 25. Avoid Clever Macros
- 26. Hidden Side Effects
- 27. Minimize Hidden Global State
- 28. Make Ownership Explicit
- 29. Error Handling Must Be Consistent
- 30. Cleanup Must Be Obvious
- 31. Avoid Deep Cleanup Mazes
- 32. State Machines Should Look Like State Machines
- 33. Separate Policy From Mechanism
- 34. Separate Hardware Access From Logic
- 35. Keep Hardware Quirks Local
- 36. Avoid Boolean Explosion
- 37. Avoid Parameter Explosion
- 38. Keep Data Structures Focused
- 39. Avoid "God Objects"
- 40. Minimize Function Parameter Context
- 41. Reduce Dependency Surface
- 42. Keep APIs Small
- 43. Avoid Leaking Implementation Details
- 44. Readability of Expressions
- 45. Operator Complexity
- 46. Magic Control Flow
- 47. Concurrency Readability
- 48. Interrupt Context
- 49. Async Code
- 50. Avoid Callback Spaghetti
- 51. Logging Quality
- 52. Logging Must Not Replace Structure
- 53. Tests Are Part of Code Quality
- 54. Test Names Should Explain Intent
- 55. Test Assertions Should Be Meaningful
- 56. Avoid Tests That Encode Accidental Behavior
- 57. Formatting Is Part of Readability
- 58. Avoid Unnecessary Formatting Changes
- 59. Keep Diffs Focused
- 60. Refactoring Scope
- 61. Preserve Behavior During Refactoring
- 62. Refactor Before Adding More Complexity
- 63. Complexity Is a Design Signal
- 64. Prefer Explicit State Over Clever Inference
- 65. Avoid Boolean State Explosion
- 66. Data Flow Should Be Visible
- 67. Avoid Unnecessary Mutation
- 68. Reduce Variable Lifetime
- 69. Avoid Reusing Variables for Different Meanings
- 70. Prefer Narrow Scope
- 71. Error Messages Should Explain Action
- 72. Avoid Defensive Programming Without Evidence
- 73. Do Not Hide Bugs With Fallbacks
- 74. Do Not Encode Measured Values as Truth
- 75. Hardware Code Must Preserve Evidence Quality
- 76. Configuration Readability
- 77. Avoid Comment Compensation
- 78. Generated Code
- 79. Dependency Hygiene
- 80. Performance vs Readability
- 81. Low-Level Optimization Comments
- 82. Architecture Should Be Visible From the Top
- 83. File Structure
- 84. Helper Function Placement
- 85. Avoid Giant Utility Files
- 86. Avoid "Miscellaneous" Abstractions
- 87. API Naming Consistency
- 88. Naming Should Encode Lifecycle
- 89. Avoid Abbreviations Unless Established
- 90. Review Like a Maintainer
- 91. The "Could I Modify It?" Test
- 92. The "Could Someone Else Debug It?" Test
- 93. Readability Before Clever Optimization
- 94. Refactoring Priority
- 95. Readability Debt
- 96. Do Not Add Comments to Rescue Bad Structure
- 97. Implementation vs Explanation
- 98. Code Smell Triggers
- 99. Complexity Budget
- 100. Preserve Simplicity
- 101. Final Code Review Pipeline
  - Pass 1 — Correctness
  - Pass 2 — Readability
  - Pass 3 — Maintainability
  - Pass 4 — Comment Quality
  - Pass 5 — Simplification
  - Pass 6 — Diff Review
- 102. Agent Finalization Rule
- 103. What the Agent Should Optimize For
- 104. What "Good Code" Means
- 105. Final Principle

</details>
