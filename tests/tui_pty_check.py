#!/usr/bin/env python3
"""通过 pty 驱动 `install.sh tools`, 校验 TUI 渲染/回车确认/选择回传。

用法: python3 tests/tui_pty_check.py
失败时退出码非 0 并打印原因; 无 pty 支持时退出码 2 (调用方按跳过处理)。
"""

import fcntl
import os
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    tmpdir = tempfile.mkdtemp(prefix="joe-tui-")
    home = os.path.join(tmpdir, "home")
    os.makedirs(home)
    stub = os.path.join(tmpdir, "stub_devtools.sh")
    with open(stub, "w") as fh:
        fh.write('#!/usr/bin/env bash\nprintf "STUB_ARGS %s\\n" "$*"\n')
    os.chmod(stub, 0o755)

    env = dict(
        os.environ,
        HOME=home,
        DEVTOOLS_SCRIPT=stub,
        TERM="xterm-256color",
        LC_ALL="C.UTF-8",
    )

    try:
        pid, fd = pty.fork()
    except OSError as exc:  # 无 pty 支持
        print("SKIP: pty 不可用 (%s)" % exc, file=sys.stderr)
        sys.exit(2)

    if pid == 0:
        os.chdir(ROOT)
        os.execvpe("bash", ["bash", "install.sh", "tools"], env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))

    chunks = []

    def drain(seconds):
        end = time.time() + seconds
        while time.time() < end:
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            chunks.append(data)

    try:
        drain(1.0)
        os.write(fd, b"a")  # 全选
        drain(0.6)
        os.write(fd, b"\r")  # 回车确认
        drain(2.0)

        exited = os.waitpid(pid, os.WNOHANG)[0] != 0
        if not exited:
            os.kill(pid, 9)
            os.waitpid(pid, 0)

        out = b"".join(chunks).decode("utf-8", "replace")
    finally:
        subprocess.run(["rm", "-rf", tmpdir], check=False)

    if "开发工具安装器" not in out:
        fail("TUI 界面未渲染到终端 (可能被命令替换捕获)")
    if "Node.js LTS" not in out:
        fail("TUI 组件列表为空 (检查 stty size / 分页计算)")
    if not exited:
        fail("按回车后 TUI 未退出 (Enter 按键未被识别)")
    if "\x1b[?25h" not in out:
        fail("退出后未恢复光标 (输出缺少 ESC[?25h)")

    match = re.search(r"STUB_ARGS (.*)", out)
    if not match:
        fail("选择结果未回传给安装器: " + repr(out[-200:]))
    args = match.group(1).split()
    if any("\x1b" in a for a in args):
        fail("ANSI 控制符泄漏进了安装参数")
    if not all(re.fullmatch(r"--[a-z]+", a) for a in args):
        fail("非法的安装参数: %r" % args)
    if args and "node" not in [a.lstrip("-") for a in args]:
        fail("全选时应包含 node")

    print("OK: TUI 渲染 %d 字节, 参数=%s" % (len(out), " ".join(args)))


if __name__ == "__main__":
    main()
