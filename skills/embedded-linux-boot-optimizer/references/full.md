# Embedded Linux Boot Optimizer — 完整参考

> 本文件是原始技能正文的完整保留，供需要细节时阅读。

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

---

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

# 2. Define "Boot Complete"

Before optimizing, determine what the user actually means by boot completion.

Possible definitions:

```text
A. Kernel reaches userspace
B. systemd reaches multi-user.target
C. SSH becomes available
D. Network is configured
E. DRM framebuffer is available
F. X11/Wayland starts
G. Chromium kiosk is visible
H. Application is ready
I. First useful frame is displayed
```

For embedded GUI systems, prefer an end-to-end definition such as:

```text
Power-on
→ Linux kernel
→ userspace
→ graphics
→ application
→ first usable frame
```

Do not optimize only the systemd number if the real application still starts slowly.

---

# 3. Establish Baseline

Collect as much information as possible.

## 3.1 Hardware

Record:

```text
SoC
CPU cores
RAM
storage type
eMMC / SD / NVMe
display hardware
USB devices
network hardware
Wi-Fi
Bluetooth
serial console
```

For Rockchip systems also record:

```text
SoC model
DDR configuration
eMMC/SD
PMIC
PHY
display controller
VOP
HDMI
DSI
CSI
USB controller
```

---

## 3.2 Kernel

Collect:

```bash
uname -a
cat /proc/cmdline
cat /proc/version
```

If available:

```bash
zcat /proc/config.gz
```

Otherwise locate the kernel config:

```bash
grep CONFIG_ /boot/config-$(uname -r)
```

Record:

```text
kernel version
config
command line
initramfs
```

---

## 3.3 systemd

Run:

```bash
systemd-analyze
systemd-analyze time
systemd-analyze blame
systemd-analyze critical-chain
```

If supported:

```bash
systemd-analyze plot > boot.svg
```

Also inspect:

```bash
systemctl list-jobs
systemctl list-units --state=failed
systemctl list-unit-files --state=enabled
```

---

## 3.4 Kernel log

Collect:

```bash
dmesg -T
```

and:

```bash
dmesg -T | grep -Ei \
'probe|defer|timeout|firmware|failed|error|reset|regulator|clock|phy'
```

Look specifically for:

```text
probe deferral
firmware timeout
MMC timeout
USB enumeration delay
PHY initialization
regulator dependency
clock dependency
DRM probe
panel probe
HDMI/DSI initialization
network PHY
```

---

## 3.5 Deferred probes

If available:

```bash
cat /sys/kernel/debug/devices_deferred
```

If debugfs is not mounted:

```bash
mount -t debugfs none /sys/kernel/debug
```

Deferred probing is often an important clue.

Do not automatically "fix" deferred probe messages.

Determine:

```text
why was it deferred?
what dependency was missing?
how long did the dependency take?
did the second probe delay boot?
```

---

# 4. Classify Boot Time

Divide total boot into layers:

```text
Boot
├── Boot ROM
├── SPL
├── U-Boot
├── Kernel decompression
├── Kernel initialization
├── initramfs
├── systemd
├── graphical stack
└── application
```

Do not optimize one layer while ignoring another.

For example:

```text
U-Boot       1.8 s
Kernel       2.1 s
systemd      4.5 s
Application  1.0 s
-------------------
Total        9.4 s
```

Optimizing a 20 ms kernel driver is irrelevant if systemd spends 2 seconds waiting for network-online.

---

# 5. U-Boot Analysis

If U-Boot is available, inspect:

```text
bootdelay
bootcmd
kernel loading
DTB loading
initrd loading
storage access
network boot
USB initialization
environment loading
```

Inspect:

```bash
printenv
```

Important variables include:

```text
bootdelay
bootcmd
boot_targets
bootargs
fdtfile
kernel_addr_r
fdt_addr_r
ramdisk_addr_r
```

Measure:

```text
power-on → U-Boot prompt
U-Boot prompt → kernel start
```

Potential optimizations:

```text
unnecessary boot target scanning
unnecessary USB initialization
unnecessary network boot attempts
long bootdelay
slow environment storage
unnecessary filesystem scanning
```

Do not remove U-Boot initialization required for the actual boot path.

---

# 6. Kernel Boot Analysis

## 6.1 initcall_debug

If boot-time kernel profiling is required, enable:

```text
initcall_debug
```

Optionally:

```text
printk.time=1
```

Useful kernel configuration:

```text
CONFIG_PRINTK_TIME=y
CONFIG_KALLSYMS=y
CONFIG_FUNCTION_TRACER=y
CONFIG_FUNCTION_GRAPH_TRACER=y
```

Then inspect:

```bash
dmesg | grep -E 'calling|initcall'
```

Depending on kernel version, output may include:

```text
calling  xxx_init+0x0/0x...
initcall xxx_init+0x0/0x... returned 0 after 12345 usecs
```

Find unusually expensive initcalls.

Do not assume the largest initcall is automatically the best optimization target.

---

# 7. Kernel Probe Analysis

Investigate slow driver probing.

Common suspects:

```text
MMC
USB
DRM
DSI
HDMI
PHY
Ethernet
Wi-Fi
Bluetooth
camera
audio
regulator
PMIC
I2C
SPI
firmware
```

Search:

```bash
dmesg -T
```

and:

```bash
dmesg -T | grep -Ei \
'probe|timeout|firmware|failed|defer'
```

Look for patterns such as:

```text
waiting for supplier
```

```text
probe deferred
```

```text
timeout waiting for ...
```

```text
failed to load firmware
```

```text
waiting for PHY
```

```text
waiting for regulator
```

The correct optimization may be:

```text
remove unnecessary device
fix Device Tree dependency
provide firmware earlier
disable unused hardware
fix probe ordering
reduce timeout
```

Do not arbitrarily shorten hardware timeouts without understanding the failure mode.

---

# 8. Device Tree Analysis

Device Tree can significantly affect boot time.

Inspect:

```text
.dts
.dtsi
.dtso
```

Look for enabled hardware:

```text
status = "okay";
```

Potential unnecessary devices:

```text
unused SPI controllers
unused I2C controllers
unused UART
unused camera
unused audio codec
unused Wi-Fi
unused Bluetooth
unused USB devices
unused display pipeline
unused sensors
unused regulators
unused PHYs
```

However:

> A device being unused by the application does not necessarily mean its node can safely be disabled.

Check dependencies:

```text
clocks
resets
power domains
regulators
phys
interrupts
GPIO
device links
suppliers
```

Before disabling a node, determine whether another component depends on it.

---

# 9. Firmware Loading

Firmware loading can introduce significant delays.

Search:

```bash
dmesg -T | grep -i firmware
```

Look for:

```text
Direct firmware load failed
waiting for firmware
firmware timeout
```

Check:

```bash
ls -lah /lib/firmware
```

Potential optimizations:

```text
remove unused firmware-dependent devices
ensure required firmware is available
avoid repeated firmware lookup failures
move required firmware into initramfs if necessary
```

Do not add firmware to initramfs automatically.

Only do so if measurement demonstrates that userspace firmware availability is delaying a critical device.

---

# 10. Deferred Probe Analysis

Deferred probe is frequently misunderstood.

A device can be deferred because a supplier has not yet registered.

Typical suppliers:

```text
regulator
clock
reset
PHY
IOMMU
power domain
GPIO
firmware
```

Investigate the dependency graph.

Useful sources:

```bash
cat /sys/kernel/debug/devices_deferred
```

and:

```bash
dmesg -T
```

If necessary inspect:

```text
/sys/kernel/debug/devices_deferred
/sys/devices
/sys/bus
```

Do not suppress deferred probe messages just to make logs cleaner.

---

# 11. systemd Analysis

Run:

```bash
systemd-analyze time
systemd-analyze blame
systemd-analyze critical-chain
```

For visualization:

```bash
systemd-analyze plot > boot.svg
```

Identify:

```text
critical-path units
long waits
serial dependencies
network-online
device units
mounts
udev
graphical target
application services
```

Important distinction:

```text
systemd-analyze blame
```

shows service activation time.

It does not necessarily show which service is responsible for delaying the final boot target.

Use:

```bash
systemd-analyze critical-chain
```

to identify the dependency path.

---

# 12. systemd Services

Before disabling a service, determine:

```bash
systemctl cat SERVICE
systemctl status SERVICE
systemctl list-dependencies SERVICE
systemctl list-dependencies --reverse SERVICE
```

Check whether it is required by:

```text
multi-user.target
graphical.target
network-online.target
application service
mount
device unit
```

Only disable services proven unnecessary for the defined boot-complete state.

Prefer:

```bash
systemctl disable SERVICE
```

over:

```bash
systemctl mask SERVICE
```

unless masking is specifically required.

Use `mask` cautiously because it prevents manual activation as well.

---

# 13. Network Boot Optimization

Networking frequently creates large boot delays.

Investigate:

```text
NetworkManager
systemd-networkd
network-online.target
wait-online services
DHCP
DNS
Wi-Fi association
Ethernet carrier detection
```

Inspect:

```bash
systemctl status NetworkManager-wait-online.service
systemctl status systemd-networkd-wait-online.service
```

Find:

```bash
systemctl list-dependencies network-online.target
```

If the application does not require network readiness before startup, determine whether the application service unnecessarily depends on:

```text
network-online.target
```

Do not disable network-online blindly.

Instead consider whether:

```text
application can start before network
```

or whether only a later subsystem actually requires the network.

---

# 14. udev Analysis

Inspect:

```bash
systemctl status systemd-udevd
journalctl -b -u systemd-udevd
```

Look for:

```text
slow device events
firmware events
persistent network naming
USB enumeration
storage devices
GPU devices
```

USB devices may introduce:

```text
enumeration delay
hub timeout
device reset
firmware loading
```

Investigate individual devices before disabling USB subsystems.

---

# 15. Snap / cloud-init / package services

Ubuntu images may contain services unnecessary for embedded products.

Potential examples:

```text
snapd
cloud-init
cloud-init-local
cloud-config
cloud-final
ModemManager
NetworkManager-wait-online
packagekit
cups
bluetooth
avahi
```

These are candidates, not automatic targets.

For each candidate determine:

```text
Is it enabled?
Is it on critical path?
Does it perform useful work?
Does the product need it?
Can it be removed rather than merely disabled?
```

Do not delete package infrastructure simply because it consumes boot time unless the product image is intentionally appliance-like.

---

# 16. initramfs

Determine whether initramfs is actually required.

Inspect:

```bash
ls -lh /boot
cat /proc/cmdline
```

Depending on distribution:

```bash
lsinitramfs /boot/initrd.img-$(uname -r)
```

Potential costs:

```text
initramfs decompression
module loading
udev
storage discovery
firmware
root filesystem discovery
cryptsetup
network initialization
```

If the platform can boot without initramfs, compare:

```text
with initramfs
vs
without initramfs
```

Do not remove initramfs if it provides required:

```text
storage driver
filesystem driver
LVM
RAID
encryption
firmware
root device
```

---

# 17. Root Filesystem and Storage

Investigate:

```text
eMMC
SD
NVMe
USB storage
ext4
f2fs
overlayfs
```

Potential bottlenecks:

```text
filesystem check
mount timeout
slow storage initialization
udev device discovery
journal replay
```

Inspect:

```bash
systemd-analyze blame
systemd-analyze critical-chain
dmesg -T
```

For embedded read-only systems consider:

```text
read-only rootfs
reduced journaling
f2fs
squashfs
overlayfs
```

Only change filesystem design when the user's product requirements permit it.

---

# 18. Graphics / DRM

Embedded GUI systems often spend significant time initializing:

```text
DRM
VOP
CRTC
encoder
connector
panel
DSI
HDMI
PHY
backlight
I2C panel controller
SPI panel
GPU
```

Inspect:

```bash
dmesg -T | grep -Ei 'drm|vop|dsi|hdmi|panel|connector|crtc|gpu'
```

Look for:

```text
panel reset delay
DSI timeout
HDMI EDID
hotplug detection
PHY calibration
firmware loading
```

Do not disable DRM components merely because they appear in the boot log.

For a fixed embedded panel, investigate whether unnecessary:

```text
EDID
HDMI detection
hotplug polling
unused connector
```

is delaying boot.

---

# 19. USB

USB initialization may include:

```text
host controller
hub enumeration
device reset
firmware
USB serial
USB storage
USB Ethernet
```

Inspect:

```bash
dmesg -T | grep -i usb
```

For a fixed product, determine whether unused USB controllers can be disabled through Device Tree.

Do not disable USB if it is needed for:

```text
console
input
storage
application device
USB gadget
```

---

# 20. MMC / eMMC / SD

Inspect:

```bash
dmesg -T | grep -Ei 'mmc|sdhci|dw_mmc'
```

Potential delays:

```text
card detection
tuning
HS200/HS400 initialization
timeouts
filesystem mount
```

Do not disable tuning or reduce initialization features simply to gain boot time unless the resulting storage mode remains reliable.

---

# 21. Audio

Audio drivers can introduce dependencies through:

```text
codec
I2C
I2S
clock
regulator
DAPM
firmware
```

For headless products, determine whether audio is actually needed during boot.

Do not disable audio if an early boot application requires it.

---

# 22. ftrace / Function Graph

When high-level measurements are insufficient, use ftrace.

Check:

```bash
mount -t tracefs nodev /sys/kernel/tracing
```

or:

```bash
mount -t debugfs none /sys/kernel/debug
```

Inspect:

```bash
ls /sys/kernel/tracing
```

Useful tracers:

```text
function
function_graph
```

Example workflow:

```bash
echo function_graph > /sys/kernel/tracing/current_tracer
echo 1 > /sys/kernel/tracing/tracing_on
```

Then reproduce the relevant operation.

Disable after measurement:

```bash
echo 0 > /sys/kernel/tracing/tracing_on
```

Do not enable extremely broad function tracing on production systems without understanding the overhead.

---

# 23. Bootchart / Visualization

When supported, generate:

```bash
systemd-analyze plot > boot.svg
```

Use visualization to answer:

```text
What starts first?
What waits?
What starts in parallel?
What is on the critical path?
```

Prefer visual timelines over isolated service durations.

---

# 24. Measurement Methodology

Boot time is noisy.

Whenever possible:

```text
reboot
measure
reboot
measure
reboot
measure
```

Prefer at least:

```text
3 runs
```

For noisy storage/network systems:

```text
5–10 runs
```

Record:

```text
minimum
median
maximum
```

Example:

```text
Baseline:
run 1: 6.81 s
run 2: 6.75 s
run 3: 6.83 s
median: 6.81 s

After change:
run 1: 5.42 s
run 2: 5.38 s
run 3: 5.47 s
median: 5.42 s
```

Do not declare a 30 ms change meaningful if measurement noise is ±100 ms.

---

# 25. Optimization Experiment Log

Every optimization should have an experiment record.

Use:

```text
Experiment:
Date:
Hardware:
Kernel:
Rootfs:
Baseline:
Hypothesis:
Change:
Expected effect:
Actual result:
Regression:
Decision:
```

Example:

```text
Experiment: BOOT-007

Baseline:
  6.81 s

Hypothesis:
  NetworkManager-wait-online is delaying multi-user.target.

Evidence:
  critical-chain shows wait-online on critical path for ~1.4 s.

Change:
  Removed unnecessary dependency on network-online.target
  from application.service.

Result:
  5.39 s

Regression:
  Application starts before network is ready.
  Application itself retries network connection.

Decision:
  KEEP
```

---

# 26. Git Workflow

If the source tree is under Git:

Before optimization:

```bash
git status
git diff
```

Create a checkpoint:

```bash
git add -A
git commit -m "boot optimization baseline"
```

For each major experiment:

```bash
git checkout -b boot-opt/<name>
```

or create a dedicated commit.

Prefer small commits:

```text
boot: disable unused bluetooth
boot: remove unnecessary wait-online dependency
boot: disable unused SPI controller
```

This allows individual changes to be reverted.

---

# 27. Automatic Regression Detection

After every optimization compare:

```text
total boot time
kernel time
userspace time
critical-chain duration
application readiness
```

A change is NOT successful if:

```text
boot time improves
but required functionality breaks
```

Also reject optimizations that create:

```text
intermittent boot failures
race conditions
network unavailable
display unavailable
USB unavailable
input unavailable
filesystem corruption
kernel warnings
```

---

# 28. Functional Validation

After every meaningful change verify the required product functions.

Examples:

```bash
ip link
ip addr
ping
ls /dev
ls /dev/dri
ls /dev/input
ls /dev/tty*
ls /dev/video*
```

For graphics:

```bash
kmscube
modetest
```

when applicable.

For USB:

```bash
lsusb
```

For storage:

```bash
mount
lsblk
```

For systemd:

```bash
systemctl --failed
```

The final boot optimization must not trade startup time for silent functional regressions.

---

# 29. Common False Optimizations

Avoid these patterns.

## 29.1 Disable everything

Bad:

```bash
systemctl disable bluetooth
systemctl disable NetworkManager
systemctl disable snapd
systemctl disable ModemManager
systemctl disable cups
...
```

without measurement.

---

## 29.2 Trust `systemd-analyze blame` blindly

A service taking 2 seconds may not delay the target if it runs in parallel.

Use:

```bash
systemd-analyze critical-chain
```

---

## 29.3 Remove kernel drivers blindly

A driver may provide:

```text
supplier
clock
regulator
PHY
power domain
```

to another driver.

---

## 29.4 Disable Device Tree nodes blindly

A node may be indirectly required by another subsystem.

---

## 29.5 Reduce timeouts globally

Changing:

```text
timeout
retry count
probe timeout
```

can hide actual hardware failures.

---

## 29.6 Optimize non-critical work

Reducing a 200 ms service that runs in parallel may produce zero boot-time improvement.

---

# 30. Decision Tree

Use this general decision process.

```text
Is boot slow?
       |
       v
Measure total time
       |
       +--> U-Boot slow?
       |       |
       |       +--> inspect boot targets/environment/storage
       |
       +--> Kernel slow?
       |       |
       |       +--> initcall_debug
       |       +--> dmesg timing
       |       +--> deferred probe
       |       +--> driver dependencies
       |
       +--> systemd slow?
       |       |
       |       +--> critical-chain
       |       +--> blame
       |       +--> device units
       |       +--> network-online
       |       +--> mounts
       |
       +--> Application slow?
               |
               +--> service dependencies
               +--> graphical stack
               +--> filesystem
               +--> application initialization
```

---

# 31. Rockchip-Specific Investigation

For Rockchip systems, pay particular attention to:

```text
VOP
DRM
DSI
HDMI
DP
PHY
IOMMU
GPU
MIPI
USB
MMC
Ethernet PHY
PMIC
regulator
clock
power-domain
```

Inspect:

```bash
dmesg -T | grep -Ei \
'rockchip|drm|vop|dsi|hdmi|phy|gpu|iommu|mmc|usb|regulator|clk'
```

If the system uses a vendor kernel, do not assume upstream behavior.

Vendor kernels frequently contain:

```text
additional drivers
different probe ordering
vendor initcalls
different power-domain behavior
different DRM stack
```

Always identify the exact kernel version and vendor tree.

---

# 32. Ubuntu Embedded Image Investigation

For Ubuntu-based embedded images inspect:

```text
systemd
NetworkManager
cloud-init
snapd
udev
ModemManager
packagekit
journald
getty
ssh
```

For appliance-like images, determine which components are genuinely required.

Typical candidates for investigation:

```text
cloud-init
snapd
ModemManager
bluetooth
cups
avahi
packagekit
wait-online
```

But candidates must be validated against the product requirements.

---

# 33. Kernel Command-Line Optimization

Inspect:

```bash
cat /proc/cmdline
```

Potentially relevant options depend on the system.

Examples include:

```text
quiet
loglevel=
earlycon
console=
root=
rootwait
rootfstype=
fsck.mode=
fsck.repair=
```

Do not remove:

```text
console
root
rootwait
earlycon
```

just because they appear unnecessary.

For production systems, logging reduction may improve perceived startup only marginally and can make diagnosis harder.

Measure before changing.

---

# 34. Parallelization

Prefer parallel startup where safe.

Look for unnecessary ordering:

```text
After=
Before=
Requires=
Wants=
RequiresMountsFor=
network-online.target
```

An unnecessary:

```text
After=network-online.target
```

can serialize an otherwise independent application.

If safe, restructure dependencies so independent tasks can start concurrently.

Do not remove ordering requirements that protect hardware or application correctness.

---

# 35. Application Service Optimization

For custom services inspect:

```bash
systemctl cat myapp.service
```

Look for:

```text
After=
Requires=
Wants=
ExecStartPre=
ExecStartPost=
Restart=
TimeoutStartSec=
Type=
```

Prefer appropriate service types.

For applications that initialize quickly and then remain resident:

```text
Type=simple
```

may be appropriate.

For applications that need explicit readiness signaling:

```text
Type=notify
```

may be appropriate if the application supports it.

Do not change service type merely to manipulate systemd's reported startup time.

The real objective is application readiness.

---

# 36. Perceived Boot Time

For GUI systems, distinguish:

```text
system boot complete
```

from:

```text
user sees useful UI
```

Measure:

```text
power-on
→ first display frame
```

when that is the real product metric.

Potential improvements:

```text
early framebuffer
early DRM
simple splash
parallel application initialization
defer nonessential services
```

Do not optimize the systemd metric while making first-frame latency worse.

---

# 37. Safe Deferral

Non-critical work can often be moved after the application becomes ready.

Candidates may include:

```text
Bluetooth
logging
telemetry
background discovery
package update services
nonessential peripherals
```

Possible approaches:

```text
systemd dependencies
systemd timers
application-level lazy initialization
udev rules
kernel module loading policy
```

But only defer work if the product does not require it during early boot.

---

# 38. Reporting Results

At the end of an optimization session produce a report:

```text
BOOT OPTIMIZATION REPORT

Hardware:
Kernel:
Rootfs:

Boot-complete definition:

Baseline:
  U-Boot:
  Kernel:
  systemd:
  Application:
  Total:

Final:
  U-Boot:
  Kernel:
  systemd:
  Application:
  Total:

Improvement:

Changes:
  1.
  2.
  3.

Functional validation:
  [x] display
  [x] network
  [x] USB
  [x] storage
  [x] application

Remaining bottlenecks:

Rejected changes:

Recommended next experiment:
```

---

# 39. Agent Behavior

When acting as an autonomous coding agent:

## Before modifying anything

Inspect:

```text
repository
kernel tree
Device Tree
systemd units
bootloader configuration
build system
deployment mechanism
```

Do not assume the build system.

Ask or discover:

```text
How is the kernel built?
How is DTB built?
How is the rootfs generated?
How is the image deployed?
How is boot time measured?
```

---

## When sufficient information is available

Do not ask unnecessary questions.

Proceed with:

```text
baseline
analysis
small experiment
measurement
```

---

## When hardware access is available

Prefer direct measurement.

For example:

```text
serial console
SSH
ADB
network shell
power-cycle controller
GPIO boot marker
```

If automated reboot is available, use it to perform repeat measurements.

---

# 40. Autonomous Optimization Loop

The preferred autonomous loop is:

```text
1. Discover system
2. Establish baseline
3. Capture logs
4. Generate boot timeline
5. Identify critical path
6. Rank hypotheses
7. Select ONE experiment
8. Save checkpoint
9. Modify configuration
10. Build
11. Deploy
12. Reboot
13. Measure
14. Validate functionality
15. Compare against baseline
16. Keep or revert
17. Record experiment
18. Repeat
```

The agent should stop when:

```text
no significant bottleneck remains
```

or:

```text
remaining bottlenecks require hardware redesign
```

or:

```text
further optimization risks required functionality
```

---

# 41. Optimization Priority

Prioritize opportunities approximately in this order:

```text
1. Hardware timeout / failed probe
2. Long critical-path dependency
3. Network-online wait
4. Storage/device discovery delay
5. U-Boot unnecessary scanning
6. Large initcall / driver probe
7. initramfs overhead
8. unnecessary service activation
9. unnecessary Device Tree devices
10. parallelization opportunities
11. non-critical background work
12. micro-optimizations
```

A 1.5-second timeout is generally more important than a 30-ms service.

---

# 42. Evidence Requirements

Before recommending a change, classify evidence:

```text
Measured
Observed
Inferred
Speculative
```

Example:

```text
Measured:
network-online.target adds 1.42 s to critical chain.

Observed:
NetworkManager-wait-online appears in the chain.

Inferred:
The application may not require network readiness.

Speculative:
Removing wait-online could reduce total boot by 1.4 s.
```

Do not present speculative improvements as guaranteed.

---

# 43. Final Rule

The agent must always prefer:

```text
evidence > intuition
measurement > assumption
critical path > blame list
one change > many changes
rollback > irreversible modification
functionality > boot-time number
```

The desired outcome is not:

```text
"systemd-analyze says 2 seconds"
```

The desired outcome is:

```text
"the embedded product reaches its required usable state
as quickly as possible, with measured evidence and no
functional regression."
```

---

# 44. Appendix — case notes: RK3588 single-app kiosk appliance (sanitized)

These notes were collected on a real **RK3588 (Rockchip 6.1 BSP) + Ubuntu 24.04 arm64**
single-application kiosk product. Internal identifiers (addresses, host names, credentials,
internal service URLs, product names) have been removed. The numbers are from that hardware
and are kept as *order-of-magnitude reference points*, not guarantees — always re-measure.

## 44.1 The product metric is "first useful frame", not `systemd-analyze`

For GUI/kiosk products, measure and record both, separately:

```text
power-on → first useful frame          (the product metric)
power-on → systemd "startup finished"  (an engineering metric)
```

On this product the two *diverged*: after the UI was removed from the boot ordering,
`systemd-analyze` reported **5.8 s** while the first frame still appeared at **≈12.7 s**,
because compositor + browser startup continued in the background.

Measurement recipe that worked:

* capture the serial console with a host-side tool that **stamps every line with host
  wall-clock time**; anchor the kernel's `printk` monotonic timestamps to it (the offset is
  constant over a capture, so it can be solved from any later line);
* `printk` / `journalctl -o short-monotonic` timestamps are CLOCK_MONOTONIC starting at
  kernel entry — they **do not include the bootloader**. Add U-Boot's self-reported total
  separately when you want "power-on → …";
* an early service can step the clock (`fake-hwclock`, NTP), skewing the first seconds of
  monotonic timestamps by up to ~1 s — compare entries on the same side of the jump, or use
  the wall-clock anchor;
* for "when did the page appear", instrument the *client*, not the port: a marker unit before
  the compositor gives compositor start; the backend's access log gives the first request.
  If the client may answer from cache, add a cache-buster parameter, otherwise the request
  never reaches the server and the timeline has a hole (this happened).

## 44.2 Cold vs steady state: a GUI app's startup can be 4x slower at boot

Same binary, same files, **same cold page cache**:

```text
steady state (drop caches, restart one unit):  ~1.4 s
at boot (whole system starting):               ~6.0 s
```

`echo 3 > /proc/sys/vm/drop_caches` reproduces *cold cache* but **not** boot-time contention.
A large gap between the two is your evidence that the bottleneck is contention, not caching.

## 44.3 Measuring "who is stealing the I/O"

* `iotop -b -o -d 1 -n N` (batch mode, only active processes) is the quickest way to see who
  reads during the boot window; record **peak** rates, not just averages.
* A sampling probe unit must be a oneshot and must **not** be `WantedBy=multi-user.target`:
  if it runs for N seconds the target waits for it, and `systemd-analyze` reports a bogus
  number (measured: 17.9 s reported while the true figure was ~5.8 s). Order it after
  `local-fs.target` and keep it off the boot-completion path.
* **Device-level truth beats per-process accounting.** In one measured 15 s window the block
  device read **84 MB**, while the sum of per-process `read_bytes` was **1.18 GB**, with a
  single long-lived process claiming 977 MB. mmap page-fault readahead is attributed to
  whichever process triggered it, so `read_bytes` over-reports badly. Cross-check with
  `/proc/diskstats` (or cgroup `io.stat` — absent on this vendor kernel, where the io
  controller was not even available). Per-process numbers are only usable as *relative*
  indicators, and only after being reconciled with the device total.
* **mmap footprint is not I/O**: summing a process's `/proc/<pid>/maps` file sizes gave
  600+ MB for a browser, while its actual cold-start read was ~75 MB. Never size a
  preload/prewarm task from the maps sum.

## 44.4 Preloading / prewarming is usually the wrong lever

Reading an application's files ahead of time only helps if that I/O window is otherwise idle.
Here it was the opposite (the boot window was I/O-saturated), so prewarming *added* traffic:
serializing it turned a 6.0 s blank into a 2.0 s blank but moved the first frame 0.9 s later
overall; running it in parallel only improved the blank to 5.3 s. Reject the approach unless
you have measured that the device is idle during the window — and prefer making fewer/smaller
files (bytecode precompilation, dropping unused plugin trees) over reading more of them.

**Bytecode precompilation** is a cheap real win for Python applications: ship the interpreter
bytecode at image-build time instead of letting the device compile sources on the first boot
(`python3 -m compileall -q <app>`, executed **inside the target rootfs** so the cache tag
matches; do it after any ownership/permission normalization so the new `__pycache__` entries
inherit the right modes). Measured gain: ~0.13-0.16 s on a ~1.9 s application start.
If the source tree is a synced snapshot that is not committed, do it in the build script
(and assert it in the image verification step: `.pyc` count ≥ `.py` count).

## 44.5 Event-driven readiness instead of polling or sleeping

The common kiosk pattern — "show a local splash page, poll the backend until it answers, then
navigate" — contains the race that *forces* the polling: before the backend listens,
connections are **refused**, so the client can only retry. Remove the race instead of tuning
the retry interval:

* let systemd **pre-bind the backend's listening socket** (`.socket` unit with
  `ListenStream=…`, `Before=<service>`), and have the service inherit the descriptor
  (`LISTEN_FDS`; e.g. Python/uvicorn takes `--fd 3`);
* the client then issues **one** request; until the backend accepts, that connection simply
  waits in the kernel's accept queue — no polling, no `sleep`, no artificial delay;
* bonus: the socket restarts a crashed backend on the next connection.

Pitfalls seen:

* the service must declare `Sockets=`; relying on same-name implicit socket activation is not
  enough — after a manual `systemctl restart <service>` the fd was not the socket and the
  service exited immediately (status 1);
* when upgrading an already-running machine, stop the old backend that holds the port first,
  otherwise the socket unit fails to bind (`Job failed`); a fresh boot has no such race;
* with the socket in place you can delete the "wait for the port" ordering and the poll loop.

## 44.6 Application-side startup flags (Chromium-based kiosk)

Browser launchers are usually wrapper scripts that source distribution snippets, and those
snippets can *suppress* flags you want. Here a distribution snippet set
`--enable-remote-extensions`, and the wrapper's rule was "only add
`--disable-background-networking` when that flag is absent" — so the product was doing
background networking at startup, which on a factory network without Internet is pure
DNS/connect timeout. Distribution files cannot be overridden by editing them, but passing
flags explicitly from a *product-owned* snippet works because explicit flags come first:

```text
--disable-background-networking --disable-component-update
--disable-domain-reliability --disable-sync
--no-first-run --no-default-browser-check
```

Verify from the running process's command line (`/proc/<pid>/cmdline`), not the config file.
Remember the benefit is only observable on a machine **without** Internet access.

## 44.7 Startup traps in the service/boot plumbing (all measured)

* `After=<network>.target` on a GUI session service serializes the whole graphical target
  behind network-manager readiness. If the product UI only needs loopback, replace it with
  "bring `lo` up" and remove the ordering.
* NetworkManager's own readiness (`Type=dbus` ⇒ "startup complete" only after activating
  connections, i.e. Wi-Fi association + DHCP) sits on the target's critical path through the
  implicit ordering that `WantedBy=` creates. If the product UI does not need the network,
  report readiness earlier (`Type=simple`) — but then every unit that genuinely needs the
  network must wait for it itself (`nm-online -s -q --timeout=N`, or `network-online.target`).
* Removing a *single* ordering dependency with a drop-in does not work on every systemd
  version: with an empty `After=` assignment the main unit's value can still win after
  drop-ins are merged (observed on systemd 255.4). Use a full unit override or restructure.
* Disable background daemons that cannot work on the product's kernel — after checking that
  the kernel really lacks their modules (example: a tracing daemon logging
  "No kernel tracer available" on every boot while reading a non-trivial amount). Keep them
  installed but not enabled so they can be started on demand.
* Services the product needs *later* should be **deferred**, not disabled: e.g. Bluetooth can
  start after the UI is up when nothing in the boot path uses it.

## 44.8 Device-tree overlays: merge at build time

Applying several device-tree overlays per boot is expensive: measured **~0.43 s per overlay**,
five overlays ≈ **2.1 s inside the bootloader**. Merging them into the base DTB at image-build
time (`fdtoverlay`) and passing a single DTB removed ~2.5 s from power-on to kernel start.
Wrap the merge so it is regenerated automatically whenever the kernel/initramfs packages are
updated, since such updates replace the boot partition's DTB tree and would otherwise leave
the bootloader pointing at a file that no longer exists.
