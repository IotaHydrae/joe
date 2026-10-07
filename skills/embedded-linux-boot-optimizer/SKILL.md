---
name: embedded-linux-boot-optimizer
description: "Measurement-driven profiling and optimization of embedded Linux boot time (U-Boot, kernel initcalls, deferred probes, Device Tree, firmware loading, systemd). Use when asked to reduce or analyze slow boot, optimize startup, or compare boot-time changes on embedded Linux / ARM SBCs. Triggers on: boot time, slow boot, optimize startup, boot bottleneck, U-Boot, initcall_debug, systemd-analyze, bootchart, kernel boot log, 启动时间, 开机慢, 启动优化, 启动分析, 启动瓶颈."
---

# Embedded Linux Boot Optimizer

## Mission

Optimize embedded Linux boot time through measurement-driven investigation.

The primary rule is:

> NEVER optimize boot time by blindly disabling services or drivers.

Every meaningful optimization must follow:

```text
Measure
  ↓
Identify bottleneck
  ↓
Form hypothesis
  ↓
Make one controlled change
  ↓
Rebuild/reboot
  ↓
Measure again
  ↓
Compare
  ↓
Keep or revert
```

The goal is not to minimize the number of processes, drivers, or services.

The goal is to minimize the time required to reach the user's defined boot-complete state while preserving required functionality.

# 1. Operating Principles

## 1.1 Measure before modifying

Before changing configuration, establish a baseline.

Never begin with:

```bash
systemctl disable ...
```

or:

```text
remove driver
disable kernel option
delete Device Tree node
disable network
disable graphical target
```

without first establishing that the component is on the critical boot path.

---

## 1.2 Optimize the critical path

A component consuming CPU time is not necessarily delaying boot.

Distinguish:

```text
CPU/runtime cost
```

from:

```text
critical-path latency
```

For systemd, prefer:

```bash
systemd-analyze critical-chain
```

over blindly interpreting:

```bash
systemd-analyze blame
```

For kernel startup, distinguish:

```text
initcall runtime
probe runtime
deferred probe
hardware timeout
firmware loading
dependency waiting
```

---

## 1.3 Change one major variable at a time

Prefer:

```text
baseline
→ disable one unnecessary service
→ measure
```

over:

```text
disable 15 services
→ reboot
→ boot is faster
→ unknown why
```

If multiple tightly coupled changes are unavoidable, document them as one experiment.

---

## 1.4 Preserve a rollback path

Before modifying:

```text
kernel configuration
Device Tree
systemd configuration
bootloader configuration
initramfs
root filesystem
```

ensure there is a known recovery path.

Preferred methods:

```bash
git status
git diff
git commit
```

or preserve explicit backups:

```bash
cp file file.bak
```

For boot-critical systems, never make an irreversible change unless recovery is known.

---

## Detailed reference

完整内容见 [`references/full.md`](references/full.md) —— 需要具体步骤、示例、检查清单时再阅读。

<details>
<summary>参考文档目录</summary>

- 2. Define "Boot Complete"
- 3. Establish Baseline
  - 3.1 Hardware
  - 3.2 Kernel
  - 3.3 systemd
  - 3.4 Kernel log
  - 3.5 Deferred probes
- 4. Classify Boot Time
- 5. U-Boot Analysis
- 6. Kernel Boot Analysis
  - 6.1 initcall_debug
- 7. Kernel Probe Analysis
- 8. Device Tree Analysis
- 9. Firmware Loading
- 10. Deferred Probe Analysis
- 11. systemd Analysis
- 12. systemd Services
- 13. Network Boot Optimization
- 14. udev Analysis
- 15. Snap / cloud-init / package services
- 16. initramfs
- 17. Root Filesystem and Storage
- 18. Graphics / DRM
- 19. USB
- 20. MMC / eMMC / SD
- 21. Audio
- 22. ftrace / Function Graph
- 23. Bootchart / Visualization
- 24. Measurement Methodology
- 25. Optimization Experiment Log
- 26. Git Workflow
- 27. Automatic Regression Detection
- 28. Functional Validation
- 29. Common False Optimizations
  - 29.1 Disable everything
  - 29.2 Trust `systemd-analyze blame` blindly
  - 29.3 Remove kernel drivers blindly
  - 29.4 Disable Device Tree nodes blindly
  - 29.5 Reduce timeouts globally
  - 29.6 Optimize non-critical work
- 30. Decision Tree
- 31. Rockchip-Specific Investigation
- 32. Ubuntu Embedded Image Investigation
- 33. Kernel Command-Line Optimization
- 34. Parallelization
- 35. Application Service Optimization
- 36. Perceived Boot Time
- 37. Safe Deferral
- 38. Reporting Results
- 39. Agent Behavior
  - Before modifying anything
  - When sufficient information is available
  - When hardware access is available
- 40. Autonomous Optimization Loop
- 41. Optimization Priority
- 42. Evidence Requirements
- 43. Final Rule
- 44. Appendix — case notes: RK3588 single-app kiosk appliance (sanitized)
  - 44.1 The product metric is "first useful frame", not `systemd-analyze`
  - 44.2 Cold vs steady state: a GUI app's startup can be 4x slower at boot
  - 44.3 Measuring "who is stealing the I/O"
  - 44.4 Preloading / prewarming is usually the wrong lever
  - 44.5 Event-driven readiness instead of polling or sleeping
  - 44.6 Application-side startup flags (Chromium-based kiosk)
  - 44.7 Startup traps in the service/boot plumbing (all measured)
  - 44.8 Device-tree overlays: merge at build time

</details>
