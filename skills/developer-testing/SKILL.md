---
name: developer-testing
description: "Design, implement and maintain a consistent, reusable and trustworthy test system: test oracles, observation vs expectation, baselines, golden data, measurement discipline. Use when writing tests, building test tooling, debugging unclear or flaky test results, or setting up project test infrastructure. Triggers on: write test, test script, test tool, oracle, baseline, golden data, measurement, verify, regression test, 写测试, 测试工具, 基准, 验证, 回归测试."
---

# Developer Testing

## Purpose

This skill defines how an AI coding agent should design, implement, maintain, and reuse project test tools.

The goal is not merely to make individual tests work.

The goal is to build a **consistent, reusable, inspectable, and trustworthy test system** over time.

The agent must behave as a maintainer of the project's testing infrastructure, not as a person writing isolated one-off scripts.

# 1. Core Principles

These principles are mandatory unless the user explicitly overrides them.

## 1.1 Reuse before creation

Before creating a new test script or helper tool:

1. Inspect the existing test infrastructure.
2. Search for existing tools with similar capabilities.
3. Search for existing tests that solve a related problem.
4. Prefer reusing an existing tool.
5. Prefer extending an existing tool over creating another similar tool.
6. Create a new tool only when existing tools cannot reasonably support the requirement.

Do not repeatedly create tools such as:

```text
test_usb.py
test_usb2.py
test_usb_new.py
usb_check.py
usb_verify.py
usb_probe_test.py
```

when one reusable `usbctl` or equivalent tool could provide the required functionality.

The test infrastructure should evolve toward a small number of composable tools rather than a large number of task-specific scripts.

---

## 1.2 Observation is not expectation

This is one of the most important rules in this skill.

A value observed during a test run is **not automatically an expected value**.

Never transform:

```text
measured value
```

into:

```text
expected value
```

without an explicit justification.

For example, this is suspicious:

```python
value = measure_sensor()

assert value == 1837
```

if `1837` was obtained only because the device happened to report `1837` during an earlier run.

The agent must be able to explain where `1837` came from.

Valid sources for an expected value include:

* hardware specification
* protocol specification
* software specification
* project requirement
* explicitly documented invariant
* approved golden/reference data
* statistically established baseline
* user-provided acceptance criterion
* mathematically derived expected value

An observed value from one run is not sufficient.

---

## 1.3 Never silently invent test criteria

The agent must not silently invent:

* expected values
* acceptable ranges
* tolerances
* timing limits
* retry counts
* golden values
* baseline values
* pass/fail thresholds

If the test requires a value that is not defined by the project, the agent should either:

1. derive it from an explicit documented rule,
2. ask the user,
3. use an explicitly defined configurable parameter,
4. or report the result as `INCONCLUSIVE` / observation-only.

Do not manufacture a specification from the first successful experiment.

---

## Detailed reference

完整内容见 [`references/full.md`](references/full.md) —— 需要具体步骤、示例、检查清单时再阅读。

<details>
<summary>参考文档目录</summary>

- 2. Test Model
- 3. Observation / Expectation / Decision
  - 3.1 Observation
  - 3.2 Expectation
  - 3.3 Decision
- 4. Test Oracles
  - 4.1 Oracle types
- 5. Oracle Declaration
- 6. The Single-Measurement Trap
- 7. Baselines
- 8. Golden Data
- 9. INCONCLUSIVE Is a Valid Result
- 10. Tool vs Test
  - Tools
  - Tests
- 11. Reusable Tool Design
- 12. CLI Conventions
- 13. Machine-Readable Output
- 14. Exit Codes
- 15. Error vs FAIL
- 16. Measurement and Parsing
- 17. Test Script Style
- 18. Explicit Units
- 19. Tolerances
- 20. Timing Tests
- 21. Hardware Tests
- 22. Serial Tests
- 23. USB Tests
- 24. Embedded-System Tests
- 25. Reset and Reproducibility
- 26. Environment Validation
- 27. Test Isolation
- 28. Cleanup
- 29. Temporary Experiments
- 30. Promotion From Experiment to Test
- 31. Naming
- 32. Directory Structure
- 33. Shared Libraries
- 34. Avoid Premature Frameworks
- 35. Dependency Policy
- 36. Versioning
- 37. Test Metadata
- 38. Test Reports
- 39. JSON Test Result Schema
- 40. Agent Investigation Order
  - Step 1 — Understand the requirement
  - Step 2 — Inspect existing infrastructure
  - Step 3 — Find reusable tools
  - Step 4 — Identify the oracle
  - Step 5 — Design the smallest change
  - Step 6 — Implement
  - Step 7 — Run
  - Step 8 — Inspect results
  - Step 9 — Report
- 41. Mandatory Pre-Test Checklist
- 42. Anti-Patterns
  - 42.1 Measurement-as-specification
  - 42.2 First-run golden value
  - 42.3 Arbitrary tolerance
  - 42.4 Duplicate tools
  - 42.5 Test-specific infrastructure
  - 42.6 Hidden assumptions
  - 42.7 Success-of-command-as-success-of-device
  - 42.8 Human-readable output as API
  - 42.9 Silent behavior changes
- 43. Regression Test Promotion
- 44. Test the Invariant, Not the Implementation
- 45. Negative Tests
- 46. Flaky Tests
- 47. Repeated Measurements
- 48. Environment-Specific Expectations
- 49. User Overrides
- 50. When Requirements Are Missing
- 51. Agent Output Requirements
- 52. Minimality
- 53. Consistency Over Cleverness
- 54. Long-Term Tool Evolution
- 55. Recommended Architecture
- 56. Example: Bad Test
- 57. Example: Good Test
- 58. Example: Observation-Only Experiment
- 59. Example: Relationship Test
- 60. Example: Reusable Serial Tool
- 61. Example: Agent Should Extend, Not Duplicate
- 62. Test Tool Review
- 63. Final Agent Rule

</details>
