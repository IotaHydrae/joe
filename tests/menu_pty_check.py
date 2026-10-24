#!/usr/bin/env python3
"""通过 pty 校验主菜单和编号安装子菜单, 安装器全部使用 stub。

用法: python3 tests/menu_pty_check.py
失败时退出码非 0; 无 pty 支持时退出码 2 (调用方按跳过处理)。
覆盖浏览、单项/全部派发、安装后留在当前菜单、失败返回和 npx 门禁。
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
MAIN_PROMPT = "选择 [1-11/q]: "
TOOLS_PROMPT = "选择操作 [1-15/b]: "
APPS_PROMPT = "选择操作 [1-6/b]: "
MCP_PROMPT = "选择操作 [1-9/b]: "
FONTS_PROMPT = "选择操作 [1-3/b]: "
TOOL_IDS = (
    "node", "python", "claude", "codex", "gemini", "opencode", "copilot",
    "grok", "mimo", "zed", "vscode", "ghostty", "godot", "ccswitch",
)
MCP_IDS = (
    "filesystem", "git", "memory", "codebase-memory-mcp", "context7",
    "codegraph", "serena", "future-service",
)
LIST_OUTPUT = """可用 MCP 服务器:
  filesystem           未配置 filesystem MCP
  git                  未配置 git MCP
  memory               已配置 memory MCP
  codebase-memory-mcp  未配置 codebase-memory MCP
  context7             未配置 Context7 MCP
  codegraph            未配置 CodeGraph MCP
  serena               未配置 Serena MCP
  future-service       未配置 Future service MCP
"""
INSTALL_MARKERS = (
    "[INFO]", "[PROGRESS]", "Installing", "正在安装", "将安装以下组件",
    "TOOLS_INSTALL|", "MCP_INSTALL|", "FONTS_INSTALL|", "SHELL_INSTALL|",
)


class MenuSession:
    def __init__(self, env, command=(), initial_prompt=MAIN_PROMPT):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.chdir(ROOT)
            os.execvpe("bash", ["bash", "install.sh", *command], env)
        self.output = bytearray()
        self.status = None
        self.initial_prompt = initial_prompt
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 100, 0, 0))

    def __enter__(self):
        try:
            self.wait_for(self.initial_prompt)
        except Exception:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, exc_type, exc, traceback):
        if self.status is None:
            try:
                os.kill(self.pid, 9)
            except ProcessLookupError:
                pass
            os.waitpid(self.pid, 0)
        os.close(self.fd)

    def read(self, timeout):
        ready, _, _ = select.select([self.fd], [], [], timeout)
        if ready:
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                return False
            self.output.extend(data)
            return bool(data)
        return True

    def wait_for(self, text, start=0):
        token = text.encode("utf-8")
        deadline = time.monotonic() + 5
        while token not in self.output[start:]:
            if time.monotonic() >= deadline or not self.read(0.1):
                raise AssertionError("未等到提示 %r, 输出: %s" % (text, self.text[-1000:]))
        return self.output[start:].decode("utf-8", "replace")

    def choose(self, choice, prompt):
        start = len(self.output)
        os.write(self.fd, choice.encode("utf-8") + b"\r")
        return self.wait_for(prompt, start)

    def finish(self):
        os.write(self.fd, b"q\r")
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            self.read(0.05)
            exited, status = os.waitpid(self.pid, os.WNOHANG)
            if exited:
                self.status = status
                if os.waitstatus_to_exitcode(status) != 0:
                    raise AssertionError("主菜单退出码非 0: %s" % self.text[-1000:])
                return
        raise AssertionError("按 q 后主菜单未退出")

    @property
    def text(self):
        return self.output.decode("utf-8", "replace")


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def plain(text):
    return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)


def main():
    try:
        probe, slave = os.openpty()
        os.close(probe)
        os.close(slave)
    except OSError as exc:
        print("SKIP: pty 不可用 (%s)" % exc, file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="joe-menu-pty-") as tmpdir:
        fakebin = os.path.join(tmpdir, "bin")
        os.makedirs(fakebin)
        # 白名单 PATH 保证宿主机已装的 AI CLI 不会影响安装列表或读取真实配置。
        for command in ("bash", "dirname", "readlink", "id", "cat", "stty"):
            binary = shutil.which(command)
            require(binary is not None, "测试缺少命令: " + command)
            os.symlink(binary, os.path.join(fakebin, command))
        devtools_stub = os.path.join(tmpdir, "devtools.sh")
        with open(devtools_stub, "w", encoding="utf-8") as handle:
            handle.write(
                '#!/usr/bin/env bash\n'
                'printf "TOOLS_INSTALL|%s\\n" "$*"\n'
                'printf "TOOLS|%s\\n" "$*" >> "$CALL_LOG"\n'
            )
        mcp_stub = os.path.join(tmpdir, "mcp.sh")
        with open(mcp_stub, "w", encoding="utf-8") as handle:
            handle.write(
                '#!/usr/bin/env bash\n'
                'if [ "${1:-}" = "--list" ]; then\n'
                '    [ "${LIST_FAIL:-0}" = 0 ] || exit 9\n'
                "    cat <<'LIST'\n" + LIST_OUTPUT + "LIST\n"
                '    exit 0\n'
                'fi\n'
                'printf "MCP_INSTALL|%s\\n" "$*"\n'
                'printf "MCP|%s\\n" "$*" >> "$CALL_LOG"\n'
                'exit "${MCP_EXIT:-0}"\n'
            )
        fonts_stub = os.path.join(tmpdir, "fonts.sh")
        with open(fonts_stub, "w", encoding="utf-8") as handle:
            handle.write(
                '#!/usr/bin/env bash\n'
                'printf "FONTS_INSTALL|%s\\n" "$*"\n'
                'printf "FONTS|%s\\n" "$*" >> "$CALL_LOG"\n'
            )
        shell_stub = os.path.join(tmpdir, "shell.sh")
        with open(shell_stub, "w", encoding="utf-8") as handle:
            handle.write(
                '#!/usr/bin/env bash\n'
                'printf "SHELL_INSTALL|%s\\n" "$*"\n'
                'printf "SHELL|%s\\n" "$*" >> "$CALL_LOG"\n'
            )
        npx_stub = os.path.join(fakebin, "npx")
        with open(npx_stub, "w", encoding="utf-8") as handle:
            handle.write("#!/usr/bin/env bash\nexit 0\n")
        os.chmod(npx_stub, 0o755)
        home = os.path.join(tmpdir, "home")
        os.makedirs(home)
        os.makedirs(os.path.join(home, ".pyenv"))
        call_log = os.path.join(tmpdir, "calls")
        env = dict(
            os.environ, TERM="xterm-256color", LC_ALL="C.UTF-8", HOME=home,
            PATH=fakebin, NVM_DIR=os.path.join(home, ".nvm"),
            DEVTOOLS_SCRIPT=devtools_stub, MCP_SCRIPT=mcp_stub, FONTS_SCRIPT=fonts_stub,
            SHELL_SCRIPT=shell_stub,
            MCP_NPX_BIN="npx", CALL_LOG=call_log, MCP_EXIT="0", LIST_FAIL="0",
        )

        with MenuSession(env) as session:
            require("Joe 开发环境配置" in session.text, "主菜单未渲染")
            for entry, title, prompt in (
                ("2", "日常软件安装", APPS_PROMPT),
                ("3", "开发工具安装", TOOLS_PROMPT),
                ("4", "MCP 服务器安装", MCP_PROMPT),
                ("6", "字体安装", FONTS_PROMPT),
            ):
                out = session.choose(entry, prompt)
                require(title in out, "未进入 " + title)
                require("全部安装" in out and "b) 返回主菜单" in out, title + "操作不完整")
                if entry == "3":
                    require("pyenv + Python (已安装)" in out, "开发工具未显示已安装状态")
                if entry == "6":
                    require("Fixedsys Excelsior" in out and "JetBrains Mono" in out, "字体菜单缺少字体")
                session.choose("", prompt)
                for invalid in ("0", "999", "zz"):
                    out = session.choose(invalid, prompt)
                    require("请输入有效编号" in out, title + "未拒绝非法编号")
                session.choose("b", MAIN_PROMPT)
            session.choose("", MAIN_PROMPT)
            out = session.choose("zz", MAIN_PROMPT)
            require("请输入有效编号" in out, "主菜单未拒绝非法输入")
            session.finish()
            require(not any(marker in session.text for marker in INSTALL_MARKERS), "浏览菜单触发安装")
            require("\x1b[?25l" not in session.text, "编号菜单仍进入了全屏 TUI")
        require(not os.path.exists(call_log), "浏览菜单调用了安装器")
        os.rmdir(os.path.join(home, ".pyenv"))

        with MenuSession(env) as session:
            out = session.choose("1", MAIN_PROMPT)
            require("SHELL_INSTALL|\r\n" in out, "菜单 1 没有派发统一 Shell 安装路径")
            session.choose("3", TOOLS_PROMPT)
            out = session.choose("2", TOOLS_PROMPT)
            require("TOOLS_INSTALL|--python" in out, "开发工具单项安装派发错误")
            require("开发工具安装" in out, "工具安装后未留在当前子菜单")
            out = session.choose("3", TOOLS_PROMPT)
            require("TOOLS_INSTALL|--node --claude\r\n" in out, "开发工具未自动补全依赖")
            out = session.choose("15", TOOLS_PROMPT)
            expected = " ".join("--" + component for component in TOOL_IDS)
            require("TOOLS_INSTALL|" + expected + "\r\n" in out, "全部工具安装派发错误或混入日常软件")
            session.choose("q", MAIN_PROMPT)
            out = session.choose("4", MCP_PROMPT)
            require("memory MCP (已配置)" in out, "MCP 未显示已配置状态")
            require("Future service MCP" in out, "MCP 新增服务被菜单隐藏")
            require(out.count("[三选一]") == 3, "MCP 代码智能缺少三选一提示")
            out = session.choose("3", MCP_PROMPT)
            require("MCP_INSTALL|memory" in out, "MCP 单项安装派发错误")
            require("MCP 服务器安装" in out, "MCP 安装后未留在当前子菜单")
            out = session.choose("9", MCP_PROMPT)
            require("MCP_INSTALL|" + " ".join(MCP_IDS) + "\r\n" in out, "MCP 全部安装派发错误")
            session.choose("b", MAIN_PROMPT)
            session.choose("6", FONTS_PROMPT)
            out = session.choose("2", FONTS_PROMPT)
            require("FONTS_INSTALL|jetbrains-mono\r\n" in out, "JetBrains Mono 单项安装派发错误")
            require("字体安装" in out, "字体安装后未留在当前子菜单")
            out = session.choose("3", FONTS_PROMPT)
            require("FONTS_INSTALL|fsex302 jetbrains-mono\r\n" in out, "字体全部安装派发错误")
            session.choose("b", MAIN_PROMPT)
            session.finish()
        with open(call_log, encoding="utf-8") as handle:
            calls = handle.read().splitlines()
        require(calls == [
            "SHELL|",
            "TOOLS|--python", "TOOLS|--node --claude", "TOOLS|" + expected,
            "MCP|memory", "MCP|" + " ".join(MCP_IDS),
            "FONTS|jetbrains-mono", "FONTS|fsex302 jetbrains-mono",
        ], "子菜单派发了额外安装操作: %r" % calls)

        previous_calls = os.path.getsize(call_log)
        with MenuSession(env, ("fonts",), FONTS_PROMPT) as session:
            require("JetBrains Mono" in session.text, "fonts 命令没有打开字体菜单")
            session.choose("b", MAIN_PROMPT)
            session.finish()
        require(os.path.getsize(call_log) == previous_calls, "直接浏览字体菜单触发安装")

        with MenuSession(dict(env, MCP_EXIT="7")) as session:
            session.choose("4", MCP_PROMPT)
            out = plain(session.choose("2", MCP_PROMPT))
            require("退出码 7" in out, "安装失败未提示退出码并返回子菜单")
            session.choose("b", MAIN_PROMPT)
            session.finish()

        previous_calls = os.path.getsize(call_log)
        with MenuSession(dict(env, MCP_NPX_BIN="joe-test-missing-npx")) as session:
            out = plain(session.choose("4", MCP_PROMPT))
            require("Node/npx: 缺失" in out, "MCP 菜单未显示 npx 缺失状态")
            for choice in ("2", "9"):
                out = session.choose(choice, MCP_PROMPT)
                require("MCP 安装需要 Node/npx" in out, "缺 npx 未给出安装提示")
                require("MCP_INSTALL|" not in out, "缺 npx 仍调用安装器")
            session.choose("b", MAIN_PROMPT)
            session.finish()
        require(os.path.getsize(call_log) == previous_calls, "缺 npx 时发生安装派发")

        with MenuSession(dict(env, LIST_FAIL="1")) as session:
            out = session.choose("4", MAIN_PROMPT)
            require("读取 MCP 列表失败" in out, "MCP 列表加载失败未提示并返回主菜单")
            session.finish()

    print("OK: 编号子菜单浏览/安装派发/返回/npx 门禁正常")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        sys.exit(1)
