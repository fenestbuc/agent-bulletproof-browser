---
name: browser-harness
description: Default browser automation via browser-use/browser-harness. Use for ALL web scraping, navigation, form filling, screenshots, and browser interaction. NEVER use Playwright or raw CDP directly.
metadata:
  hermes:
    tags: [browser, cdp, automation, browser-use, chromium, devtools]
---

# browser-harness

browser-harness is the ONLY browser automation tool. Do not use Playwright, Selenium, or raw CDP automation. Always invoke `browser-harness` directly.

## Install

Clone to a stable path and install as editable so agent edits to `agent-workspace/agent_helpers.py` take effect immediately:

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/browser-use/browser-harness.git
cd browser-harness
uv tool install -e .
command -v browser-harness
```

## Connect to a local browser

### Way 1: Real profile (preferred for interactive tasks)

Use the user's everyday Chromium with existing logins, extensions, and cookies.

1. Launch Chromium and open the remote-debugging page:
   ```bash
   chromium-browser "chrome://inspect/#remote-debugging"
   ```
2. Tick **"Allow remote debugging for this browser instance"** (sticky per profile).
3. Click **Allow** if an in-browser popup appears (Chrome 144+).
4. Test:
   ```bash
   browser-harness -c 'print(page_info())'
   ```

### Way 2: Background automation (No popups / Safe lifecycle)

For all background, scheduled, or agentic automation, **always** use the dedicated lifecycle wrapper script. This script automatically starts Chromium natively (`--headless=new`), injects permission to download files to `~/Downloads/agent-downloads`, runs the given python script, and then securely tears down the browser to prevent memory leaks and zombie processes. 

It also utilizes `flock` to queue concurrent executions. If multiple subagents attempt browser tasks simultaneously, they will wait in line rather than corrupting the profile or stealing tab focus.

```bash
run-agent-headless "
new_tab('https://example.com')
wait_for_load()
print(page_info())
"
```

**Critical:** `--user-data-dir` must NOT be the platform default (`~/.config/chromium` on Linux, `~/Library/Application Support/Google/Chrome` on macOS, `%LOCALAPPDATA%\Google\Chrome\User Data` on Windows). Chrome 136+ silently ignores `--remote-debugging-port` when the default profile is used.

## First-time troubleshooting

Run diagnostics before asking the user:

```bash
browser-harness --doctor
```

Match output to action:

| chrome | daemon | fix |
|--------|--------|-----|
| FAIL   | --     | Launch Chromium (Way 1 or Way 2) |
| ok     | FAIL   | Enable `chrome://inspect/#remote-debugging` checkbox; click Allow on popup |
| ok     | ok     | Stale daemon -- `browser-harness -c 'restart_daemon()'` |

If restart hangs, kill daemon and socket manually:
```bash
pkill -f browser_harness.daemon
rm -f /tmp/bu-default.sock /tmp/bu-default.pid
```

## One-liner shape

```bash
browser-harness -c '
new_tab("https://example.com")
wait_for_load()
print(page_info())
'
```

- `browser-harness` is on PATH. No cd, no uv run.
- First navigation is `new_tab(url)`, not `goto_url(url)`. `goto_url` clobbers the user's active tab.

## Pre-imported helpers

- `new_tab(url)`, `goto_url(url)`, `wait_for_load()`, `page_info()`
- `click_at_xy(x, y)` -- preferred over selectors. Click coordinates from screenshots.
- `capture_screenshot()` -- returns file path string (e.g. `/tmp/shot.png`).
- `js(expression)` -- `Runtime.evaluate` wrapper.
- `cdp(method, **params)` -- raw CDP when helpers don't cover it.
- `list_tabs()`, `current_tab()`, `switch_tab(target)`, `ensure_real_tab()`
- `http_get(url)` -- bulk HTTP, no browser overhead.

## Core workflow
 
1. Screenshot first: `capture_screenshot()` to understand the page.
2. Click from image: read pixel coordinates, `click_at_xy(x, y)`. **DOM-selector guessing is explicitly forbidden on modern sites (React/Cloudflare/Notion/X).** Use vision-based clicks.
3. Verify with another screenshot.
4. Only drop to DOM (`js(...)`) when the target has no visible geometry, and rely strictly on text-content matching, not CSS classes.

## Remote browsers (optional)

Requires `BROWSER_USE_API_KEY`.

```bash
browser-harness -c 'start_remote_daemon("work")'
BU_NAME=work browser-harness -c 'new_tab("https://example.com")'
```

## Daemon control

```bash
browser-harness --doctor          # version, chrome state, daemon state, updates
browser-harness -c 'restart_daemon()'  # restart if stale
browser-harness --update -y       # pull latest (editable clone: git pull --ff-only)
```

## Architecture

```
Chrome -> CDP WebSocket -> browser_harness.daemon -> IPC Unix socket -> browser-harness CLI
```

- IPC socket: `/tmp/bu-<NAME>.sock` (POSIX)
- `BU_NAME` namespaces daemon IPC, pid, and log files
- `BU_CDP_WS` overrides local Chrome discovery for remote browsers
- `BU_CDP_URL` sets a specific DevTools HTTP endpoint

## Maintenance

- `browser-harness` prints an update banner once per day when a newer release exists.
- Run `browser-harness --update -y` yourself; do not ask the user.
- `--update` refuses on editable clones with uncommitted changes. If dirty, tell the user.

## References

- `references/background-architecture.md` -- Design rationale for headless=new, multi-agent concurrency (flock), and resilience (trap/timeout) in background automation wrappers
- `references/install-troubleshooting.md` -- session-specific errors, Wayland/Ozone quirks, and reproduction recipes
- `references/cloudflare-dashboard-automation.md` -- why React custom dropdowns on dash.cloudflare.com resist automation and what to do instead
- `references/gcp-console-automation.md` -- Google Cloud Console bot detection limits and alternative paths for service account key generation
- `references/notion-automation.md` -- Notion UI automation: left-then-right-click patterns, accessibility tree bridging, and when to stop fighting the UI
- `scripts/run-hermes-headless.sh` -- the mandatory wrapper for background automation. Use its absolute path: `~/.hermes/skills/devops/browser-harness/scripts/run-hermes-headless.sh`.
- `scripts/start-hermes-browser.sh` -- the foreground login helper for the user. Use its absolute path: `~/.hermes/skills/devops/browser-harness/scripts/start-hermes-browser.sh`.

## Pitfalls

- **Browser preference: use Chromium, not Brave.** Brave's process model and CDP behavior differ from Chromium. Always launch `chromium-browser` or `chromium`.
- **`js()` escaping errors with multiline scripts.** Passing complex JavaScript with nested quotes or regexes (e.g., `replace(/\n/g)`) inside `browser-harness -c '... js("""...""")'` often fails with `SyntaxError: missing ) after argument list` due to bash and python `exec()` escaping clashes (backslashes and inner quotes get swallowed). **Fix:** Heavily simplify the JS or use coordinate clicks. **NEVER drop down to raw `websocket` Python scripts.** Raw CDP scripts are strictly forbidden. Always route through `browser-harness` via `BU_CDP_URL`.
- **`-c` scripts are sync only.** The CLI runs `exec(code, globals())`. There is no event loop, so `await`, `asyncio.run()`, and async helper names (`goto`, `page`) do not exist. Use the pre-imported synchronous helpers (`goto_url`, `page_info`, `js`, `click_at_xy`, `wait`) only.
- **`switch_tab` does not accept integer indices.** Pass a `targetId` string or the dict from `current_tab()` / `list_tabs()`. `switch_tab(-1)` raises `Invalid parameters`.
- **Way 2 with default profile silently fails.** Chrome 136+ ignores `--remote-debugging-port` when `--user-data-dir` points to the platform default.
- **Only one CDP client per tab.** If another tool is attached, browser-harness may fail to attach.
- **Popups on Chrome 144+.** Way 1 triggers an "Allow remote debugging?" popup on first attach. The user must click Allow.
- **Auth wall (redirected to login) → stop and ask the user.** Do not type credentials.
- **React/custom dropdowns resist automation.** Framework-managed select components (e.g., Cloudflare dashboard) often ignore `click_at_xy` and CDP mouse events. The dropdown DOM may update but the listbox never opens. When this happens, switch to the CLI-native auth flow (e.g., `wrangler login`) rather than fighting the UI.
- **Obfuscated class names → find by text.** Sites like Cloudflare use generated class names (`c_di c_fo`). Do not try to build CSS selectors. Use `js()` to scan by text content:
  ```python
  js("Array.from(document.querySelectorAll('*')).filter(e => e.textContent && e.textContent.trim() === 'Target Text').map(e => e.getBoundingClientRect())")
  ```