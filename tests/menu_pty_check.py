#!/usr/bin/env python3
"""通过 pty 驱动 `install.sh` 主菜单, 校验渲染/输入处理/干净退出。

用法: python3 tests/menu_pty_check.py
失败时退出码非 0; 无 pty 支持时退出码 2 (调用方按跳过处理)。
测试只走空输入、非法编号和 q, 不会触发任何安装动作。
"""

import fcntl
import os
import pty
import re
import select
import struct
import sys
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INSTALL_MARKERS = ("[INFO]", "[PROGRESS]", "Installing", "正在安装", "将安装以下组件")


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    env = dict(os.environ, TERM="xterm-256color", LC_ALL="C.UTF-8")

    try:
        pid, fd = pty.fork()
    except OSError as exc:
        print("SKIP: pty 不可用 (%s)" % exc, file=sys.stderr)
        sys.exit(2)

    if pid == 0:
        os.chdir(ROOT)
        os.execvpe("bash", ["bash", "install.sh"], env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 100, 0, 0))
    chunks = bytearray()

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
            chunks.extend(data)

    drain(1.5)
    os.write(fd, b"\r")          # 空输入: 只重绘, 不安装
    drain(0.8)
    os.write(fd, b"zz\r")        # 非法编号
    drain(0.8)
    os.write(fd, b"q\r")         # 退出
    drain(1.5)

    exited = os.waitpid(pid, os.WNOHANG)[0] != 0
    if not exited:
        os.kill(pid, 9)
        os.waitpid(pid, 0)

    out = chunks.decode("utf-8", "replace")

    if "Joe 开发环境配置" not in out:
        fail("菜单未渲染")
    if not re.search(r"已装 \d+/\d+", out):
        fail("菜单缺少工具装机数")
    if out.count("选择 [1-9/q]") < 3:
        fail("空输入或非法编号后菜单没有重绘 (只出现 %d 次)" % out.count("选择 [1-9/q]"))
    if "请输入有效编号" not in out:
        fail("非法编号未给出提示")
    leaked = [m for m in INSTALL_MARKERS if m in out]
    if leaked:
        fail("菜单浏览触发了安装动作: %s" % leaked)
    if not exited:
        fail("按 q 后菜单没有退出")

    print("OK: 主菜单渲染正常, 浏览未触发安装, q 干净退出")


if __name__ == "__main__":
    main()
