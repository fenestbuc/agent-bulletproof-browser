#!/usr/bin/env python3
"""Browser lifecycle guard: ensures child Chromium dies with its parent.

On Linux, attempts prctl(PR_SET_PDEATHSIG, SIGKILL).
On all platforms, falls back to a PPID watcher.
"""

import ctypes
import os
import signal
import subprocess
import sys
import time


def write_pid(pid: int, pidfile: str) -> None:
    """Write child PID to a file for external tracking."""
    if not pidfile:
        return
    try:
        with open(pidfile, "w") as fh:
            fh.write(str(pid))
    except Exception:
        pass


def set_pdeathsig() -> None:
    """Set PR_SET_PDEATHSIG so kernel sends SIGKILL if parent dies."""
    try:
        libc = ctypes.CDLL("libc.so.6")
        libc.prctl(1, signal.SIGKILL)  # PR_SET_PDEATHSIG = 1
    except Exception:
        pass


def run_with_prctl(chrome_bin: str, args: list[str], pidfile: str) -> int:
    """Launch chrome with prctl preexec."""
    set_pdeathsig()
    proc = subprocess.Popen([chrome_bin] + args, preexec_fn=set_pdeathsig)
    write_pid(proc.pid, pidfile)

    def on_term(signum, frame):
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_term)
    return proc.wait()


def run_with_ppid_watch(chrome_bin: str, args: list[str], pidfile: str) -> int:
    """Launch chrome and watch parent PID; kill chrome if parent vanishes."""
    proc = subprocess.Popen([chrome_bin] + args)
    write_pid(proc.pid, pidfile)
    original_ppid = os.getppid()

    def on_term(signum, frame):
        proc.terminate()
        time.sleep(2)
        try:
            os.kill(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, on_term)
    while proc.poll() is None:
        if os.getppid() != original_ppid:
            proc.terminate()
            time.sleep(2)
            try:
                os.kill(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            break
        time.sleep(1)
    return proc.returncode or 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: browser-guard.py <chrome-bin> [chrome-args...]", file=sys.stderr)
        return 1

    chrome_bin = sys.argv[1]
    chrome_args = sys.argv[2:]
    pidfile = os.environ.get("AGENT_CHILD_PID_FILE", "")

    try:
        return run_with_prctl(chrome_bin, chrome_args, pidfile)
    except Exception:
        return run_with_ppid_watch(chrome_bin, chrome_args, pidfile)


if __name__ == "__main__":
    sys.exit(main())
