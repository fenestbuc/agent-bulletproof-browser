# Background Architecture Reference

Session: 2026-06-03. Evolution of the background automation wrapper and the "Chain of Death" implementation.

## The Problem
Background browser automation via raw CDP faces several severe architectural failure modes:
1. **The Xvfb/Keyring Disconnect:** Running isolated profiles via `Xvfb` dummy displays breaks OS keyring decryption (e.g. GNOME password store), instantly invalidating stored session cookies for modern sites like X/Twitter and LinkedIn.
2. **Process Fratricide (Multi-Agent Collisions):** Multiple subagents or overlapping cron jobs attempting to launch browsers or bind to port 9222 simultaneously crash the browser or overwrite the profile database lock.
3. **Infinite Queues & Deadlocks:** If a navigation event hangs indefinitely waiting for network idle, the background script hangs forever, blocking the entire automation queue.
4. **The `SIGKILL` Orphan Zombie Loop:** Standard bash `trap` commands catch graceful terminations (`SIGTERM`, `SIGINT`), but if the wrapper is murdered with `kill -9` (e.g. OOM killer or hard task abort), the child headless Chromium instance is orphaned. It stays alive forever, permanently jamming port 9222 and hoarding RAM.
5. **Headless Download Blocks:** Chromium natively blocks all file downloads when launched with `--headless=new` for security reasons.

## The Optimal Architecture (`run-agent-headless`)
The final wrapper script systematically mitigates all five failure modes to provide absolute multi-agent resilience.

### 1. Keyring Bypass
Uses `--password-store=basic` to permanently decouple the automation profile (`agent-automation-bg`) from the Linux desktop keyring. Cookies decrypt cleanly in headless mode.

### 2. POSIX File Queuing (`flock`)
Instead of racing to bind to port 9222, the script acquires an exclusive POSIX file lock (`/tmp/agent-browser-bg-<uid>.lock`). Concurrent subagents are safely queued. On macOS, where `flock` may not be available, the script falls back to atomic `mkdir` locks.

### 3. Graceful Aborts (`timeout`)
The entire `browser-harness` execution block is wrapped in an OS-level `timeout` (default 300s). Infinite page loads trigger a forced exit, safely releasing the lock for the next subagent.

### 4. Headless Downloads
Pre-injects `cdp('Browser.setDownloadBehavior', behavior='allow', downloadPath='$DOWNLOAD_DIR', eventsEnabled=True)` directly before the target automation python block.

### 5. The "Chain of Death" (`prctl` + PPID Watch Fallback)
To achieve immunity to `SIGKILL` orphan zombies on Linux, Chromium is launched through a `ctypes` Python shim that invokes `prctl(PR_SET_PDEATHSIG, SIGKILL)`. If the parent script dies, the kernel instantly fires a `SIGKILL` down the chain.

On macOS (where `prctl` does not exist), the Python shim instead monitors its parent PID in a tight loop. If the parent dies and the child is re-parented to PID 1, the shim terminates Chromium and exits. This is not kernel-level but is robust enough for production use.