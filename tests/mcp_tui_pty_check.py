#!/usr/bin/env python3
"""通过 pty 驱动 MCP TUI, 校验渲染、选择回传和 Node/npx 依赖门禁。

用法: python3 tests/mcp_tui_pty_check.py
失败时退出码非 0; 无 pty 支持时退出码 2 (调用方按跳过处理)。
安装器用 stub 替身, 不会真正写入任何 AI CLI 配置。
"""

import fcntl
import os
import pty
import re
import select
import shutil
import struct
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LIST_OUTPUT = """可用 MCP 服务器:
  filesystem            未配置 filesystem MCP
  git                   未配置 git MCP
  memory                已配置 memory MCP
  codebase-memory-mcp   未配置 codebase-memory MCP
  context7              未配置 context7 MCP
  codegraph             未配置 codegraph MCP
  serena                未配置 serena MCP
"""


def fail(msg):
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def drain(fd, buf, seconds):
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.2)
        if not ready:
            continue
        try:
            data = os.read(fd, 65536)
        except OSError:
            return
        if not data:
            return
        buf.extend(data)


def run_case(env_extra, keys):
    """启动一次 `install.sh mcp`, 返回 (退出码, 输出, 是否正常退出)。"""
    env = dict(os.environ, TERM="xterm-256color", LC_ALL="C.UTF-8", **env_extra)
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        os.execvpe("bash", ["bash", "install.sh", "mcp"], env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 110, 0, 0))
    buf = bytearray()
    drain(fd, buf, 3.0)          # --list 检测
    for key in keys:
        os.write(fd, key)
        drain(fd, buf, 0.8)
    drain(fd, buf, 1.5)

    exited = os.waitpid(pid, os.WNOHANG)[0] != 0
    if not exited:
        try:
            os.kill(pid, 9)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
        code = None
    else:
        # 子进程已回收; 取不到原始退出码时用 None 表示"已退出"
        code = "exited"
    return code, buf.decode("utf-8", "replace")


def main():
    tmpdir = tempfile.mkdtemp(prefix="joe-mcp-tui-")
    try:
        stub = os.path.join(tmpdir, "mcp_stub.sh")
        with open(stub, "w") as fh:
            fh.write(
                "#!/usr/bin/env bash\n"
                "if [ \"$1\" = \"--list\" ]; then\n"
                "cat <<'LIST'\n" + LIST_OUTPUT + "LIST\n"
                "exit 0\n"
                "fi\n"
                "printf 'INSTALL:[%s]\\n' \"$*\"\n"
            )
        os.chmod(stub, 0o755)

        fakebin = os.path.join(tmpdir, "bin")
        os.makedirs(fakebin)
        with open(os.path.join(fakebin, "npx"), "w") as fh:
            fh.write("#!/usr/bin/env bash\nexit 0\n")
        os.chmod(os.path.join(fakebin, "npx"), 0o755)

        try:
            probe_fd, _ = os.openpty()
            os.close(probe_fd)
        except OSError as exc:
            print("SKIP: pty 不可用 (%s)" % exc, file=sys.stderr)
            return 2

        base = {"MCP_SCRIPT": stub, "HOME": os.path.join(tmpdir, "home")}
        os.makedirs(base["HOME"], exist_ok=True)

        # 正路径: npx 可用, 全选后回车
        code, out = run_case(dict(base, PATH=fakebin + ":" + os.environ["PATH"]), [b"a", b"\r"])
        if code is None:
            fail("按回车后 MCP TUI 未退出")
        if "MCP 服务器选择" not in out or "代码智能（三选一）" not in out:
            fail("MCP TUI 未渲染分组标题")
        if out.count("[三选一]") < 3:
            fail("代码智能没有三选一标记")
        if "已配置" not in out:
            fail("没有显示已配置状态")
        if "\x1b[?25h" not in out:
            fail("退出后未恢复光标")
        match = re.search(r"INSTALL:\[(.*?)\]", out)
        if not match:
            fail("选择结果没有回传给安装器")
        ids = match.group(1).split()
        for expected in ("filesystem", "memory", "serena"):
            if expected not in ids:
                fail("回传的 id 缺少 %s: %r" % (expected, ids))

        # 负路径: npx 缺失时不得调用安装器
        code, out = run_case(dict(base, MCP_NPX_BIN="joe-missing-npx"), [b"a", b"\r"])
        if code is None:
            fail("缺少 npx 时 MCP TUI 未退出")
        if "MCP 安装需要 Node/npx" not in out:
            fail("缺少 npx 时没有给出安装提示")
        if "INSTALL:" in out:
            fail("缺少 npx 时仍调用了安装器")
        plain = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", out)
        if "Node/npx: 缺失" not in plain:
            fail("状态栏没有显示 Node/npx 缺失")

        print("OK: MCP TUI 渲染/选择回传/npx 门禁正常")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
