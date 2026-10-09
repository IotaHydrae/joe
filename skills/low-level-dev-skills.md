# low-level-dev-skills 技能集

来源：[mohitmishra786/low-level-dev-skills](https://github.com/mohitmishra786/low-level-dev-skills)。
固定提交：`bdc58472fa9f309ed1b3f7d985a0d8e9bd8f4608`；导入日期：2026-10-09。

导入 **142 个独立技能、25 个分类**。每个技能保留参考文件，并附带上游 MIT 许可证和 `SOURCE.md` 来源记录。
跨技能引用转换为 joe 的 `skills/<name>`；参考文档仍按需加载。安装技能不会安装编译器、调试器、内核模块或其他系统工具，也不会自动安装相关技能。

## 按需选择

从仓库根目录运行：

```bash
./install.sh skills --categories
./install.sh skills --category kernel-dev --tui
./install.sh skills --category compilers --category debuggers --tui
./install.sh skills device-tree gdb cross-gcc
./install.sh skills --category kernel-dev --all  # 显式安装该分类全部技能
```

分类过滤可与 `--list`、`--tui`、`--all` 和技能名组合，重复 `--category` 取并集。默认不勾选任何技能。原有技能和自定义技能归入 `local` 分类。

## 分类目录

| 分类 | 数量 | 技能 |
|---|---:|---|
| `allocators` | 2 | [custom-allocators](custom-allocators/SKILL.md), [numa-programming](numa-programming/SKILL.md) |
| `async-io` | 3 | [af-xdp](af-xdp/SKILL.md), [dpdk](dpdk/SKILL.md), [io-uring](io-uring/SKILL.md) |
| `baremetal` | 14 | [adc-dac-baremetal](adc-dac-baremetal/SKILL.md), [baremetal-startup](baremetal-startup/SKILL.md), [bootloaders-embedded](bootloaders-embedded/SKILL.md), [datasheet-and-refmanual-reading](datasheet-and-refmanual-reading/SKILL.md), [dma-baremetal](dma-baremetal/SKILL.md), [gpio-baremetal](gpio-baremetal/SKILL.md), [interrupts-and-exceptions-baremetal](interrupts-and-exceptions-baremetal/SKILL.md), [low-power-embedded](low-power-embedded/SKILL.md), [mmio-and-bit-manipulation](mmio-and-bit-manipulation/SKILL.md), [peripherals-from-datasheet](peripherals-from-datasheet/SKILL.md), [spi-i2c-baremetal](spi-i2c-baremetal/SKILL.md), [stm32-baremetal](stm32-baremetal/SKILL.md), [timers-pwm-baremetal](timers-pwm-baremetal/SKILL.md), [uart-serial-baremetal](uart-serial-baremetal/SKILL.md) |
| `binaries` | 4 | [binutils](binutils/SKILL.md), [dynamic-linking](dynamic-linking/SKILL.md), [elf-inspection](elf-inspection/SKILL.md), [linkers-lto](linkers-lto/SKILL.md) |
| `build-systems` | 9 | [bazel](bazel/SKILL.md), [build-acceleration](build-acceleration/SKILL.md), [cmake](cmake/SKILL.md), [conan-vcpkg](conan-vcpkg/SKILL.md), [include-what-you-use](include-what-you-use/SKILL.md), [make](make/SKILL.md), [meson](meson/SKILL.md), [ninja](ninja/SKILL.md), [static-analysis](static-analysis/SKILL.md) |
| `compiler-internals` | 7 | [code-generation-and-backends](code-generation-and-backends/SKILL.md), [compiler-frontend](compiler-frontend/SKILL.md), [compiler-optimizations-deep](compiler-optimizations-deep/SKILL.md), [jit-compilation](jit-compilation/SKILL.md), [llvm-ir-and-passes](llvm-ir-and-passes/SKILL.md), [llvm-passes](llvm-passes/SKILL.md), [mlir](mlir/SKILL.md) |
| `compilers` | 8 | [clang](clang/SKILL.md), [cpp-modules](cpp-modules/SKILL.md), [cpp-templates](cpp-templates/SKILL.md), [cross-gcc](cross-gcc/SKILL.md), [gcc](gcc/SKILL.md), [llvm](llvm/SKILL.md), [msvc-cl](msvc-cl/SKILL.md), [pgo](pgo/SKILL.md) |
| `computer-architecture` | 5 | [abi-and-calling-conventions](abi-and-calling-conventions/SKILL.md), [branch-prediction-and-speculation](branch-prediction-and-speculation/SKILL.md), [cpu-pipelines-and-hazards](cpu-pipelines-and-hazards/SKILL.md), [memory-hierarchy-and-caches](memory-hierarchy-and-caches/SKILL.md), [virtual-memory-paging-and-tlb](virtual-memory-paging-and-tlb/SKILL.md) |
| `debuggers` | 6 | [concurrency-debugging](concurrency-debugging/SKILL.md), [core-dumps](core-dumps/SKILL.md), [debug-optimized-builds](debug-optimized-builds/SKILL.md), [dwarf-debug-format](dwarf-debug-format/SKILL.md), [gdb](gdb/SKILL.md), [lldb](lldb/SKILL.md) |
| `embedded` | 5 | [embedded-rust](embedded-rust/SKILL.md), [freertos](freertos/SKILL.md), [linker-scripts](linker-scripts/SKILL.md), [openocd-jtag](openocd-jtag/SKILL.md), [zephyr](zephyr/SKILL.md) |
| `gpu` | 6 | [cuda](cuda/SKILL.md), [cuda-debugging](cuda-debugging/SKILL.md), [cuda-profiling](cuda-profiling/SKILL.md), [gpu-memory-model](gpu-memory-model/SKILL.md), [hip-rocm](hip-rocm/SKILL.md), [triton-lang](triton-lang/SKILL.md) |
| `hpc` | 3 | [mpi](mpi/SKILL.md), [openmp](openmp/SKILL.md), [rdma-verbs](rdma-verbs/SKILL.md) |
| `kernel` | 5 | [device-drivers](device-drivers/SKILL.md), [kernel-debugging](kernel-debugging/SKILL.md), [kernel-internals](kernel-internals/SKILL.md), [kernel-testing](kernel-testing/SKILL.md), [os-dev-scratch](os-dev-scratch/SKILL.md) |
| `kernel-dev` | 9 | [bus-drivers-i2c-spi](bus-drivers-i2c-spi/SKILL.md), [device-tree](device-tree/SKILL.md), [kernel-concurrency](kernel-concurrency/SKILL.md), [kernel-debugging-advanced](kernel-debugging-advanced/SKILL.md), [kernel-memory-management](kernel-memory-management/SKILL.md), [linux-kernel-architecture](linux-kernel-architecture/SKILL.md), [platform-device-model](platform-device-model/SKILL.md), [qemu-for-kernel-development](qemu-for-kernel-development/SKILL.md), [writing-char-drivers](writing-char-drivers/SKILL.md) |
| `languages` | 2 | [carbon-lang](carbon-lang/SKILL.md), [hare-lang](hare-lang/SKILL.md) |
| `low-level-programming` | 9 | [assembly-arm](assembly-arm/SKILL.md), [assembly-riscv](assembly-riscv/SKILL.md), [assembly-x86](assembly-x86/SKILL.md), [cpp-coroutines](cpp-coroutines/SKILL.md), [cpu-cache-opt](cpu-cache-opt/SKILL.md), [interpreters](interpreters/SKILL.md), [linux-kernel-modules](linux-kernel-modules/SKILL.md), [memory-model](memory-model/SKILL.md), [simd-intrinsics](simd-intrinsics/SKILL.md) |
| `observability` | 2 | [ebpf](ebpf/SKILL.md), [ebpf-rust](ebpf-rust/SKILL.md) |
| `platform` | 3 | [apple-silicon](apple-silicon/SKILL.md), [arm-sve](arm-sve/SKILL.md), [riscv-privileged](riscv-privileged/SKILL.md) |
| `profilers` | 7 | [flamegraphs](flamegraphs/SKILL.md), [hardware-counters](hardware-counters/SKILL.md), [heaptrack](heaptrack/SKILL.md), [intel-vtune-amd-uprof](intel-vtune-amd-uprof/SKILL.md), [linux-perf](linux-perf/SKILL.md), [strace-ltrace](strace-ltrace/SKILL.md), [valgrind](valgrind/SKILL.md) |
| `qemu` | 4 | [protocol-analysis](protocol-analysis/SKILL.md), [qemu-embedded-simulation](qemu-embedded-simulation/SKILL.md), [resource-optimization-lowend](resource-optimization-lowend/SKILL.md), [verilog-basics-for-lowlevel](verilog-basics-for-lowlevel/SKILL.md) |
| `runtimes` | 5 | [binary-hardening](binary-hardening/SKILL.md), [fuzzing](fuzzing/SKILL.md), [sanitizers](sanitizers/SKILL.md), [wasm-emscripten](wasm-emscripten/SKILL.md), [wasm-wasmtime](wasm-wasmtime/SKILL.md) |
| `rust` | 12 | [cargo-workflows](cargo-workflows/SKILL.md), [rust-async-internals](rust-async-internals/SKILL.md), [rust-build-times](rust-build-times/SKILL.md), [rust-cross](rust-cross/SKILL.md), [rust-debugging](rust-debugging/SKILL.md), [rust-ffi](rust-ffi/SKILL.md), [rust-no-std](rust-no-std/SKILL.md), [rust-profiling](rust-profiling/SKILL.md), [rust-sanitizers-miri](rust-sanitizers-miri/SKILL.md), [rust-security](rust-security/SKILL.md), [rust-unsafe](rust-unsafe/SKILL.md), [rustc-basics](rustc-basics/SKILL.md) |
| `security` | 2 | [kernel-security](kernel-security/SKILL.md), [reverse-engineering](reverse-engineering/SKILL.md) |
| `virtualization` | 3 | [containers-internals](containers-internals/SKILL.md), [hypervisor-internals](hypervisor-internals/SKILL.md), [qemu-kvm](qemu-kvm/SKILL.md) |
| `zig` | 7 | [zig-build-system](zig-build-system/SKILL.md), [zig-cinterop](zig-cinterop/SKILL.md), [zig-compiler](zig-compiler/SKILL.md), [zig-comptime](zig-comptime/SKILL.md), [zig-cross](zig-cross/SKILL.md), [zig-debugging](zig-debugging/SKILL.md), [zig-testing](zig-testing/SKILL.md) |
