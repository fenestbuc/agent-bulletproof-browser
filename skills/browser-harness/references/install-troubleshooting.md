# browser-harness install troubleshooting reference

Session: 2026-05-06. Fedora 43, Chromium 147.0.7727.137, Wayland/Ozone.

## Connection setup on Linux (Wayland)

### Launching Chromium for Way 1

On Fedora with Wayland, the simple command works:

```bash
chromium-browser "chrome://inspect/#remote-debugging"
```

Do NOT use Brave. User explicitly corrected: use Chromium only.

If Chromium is already running, launching a second instance with the same profile prints:
```
Opening in existing browser session.
```
and exits without opening a new window. To force a new window on the same profile:
```bash
chromium-browser --new-window "chrome://inspect/#remote-debugging"
```

### Way 2 on Linux (Dedicated Automation Profile)

```bash
chromium-browser --remote-debugging-port=9222 \
  --user-data-dir=$HOME/.config/chromium/hermes-automation \
  --remote-allow-origins='*' &
export BU_CDP_URL=http://127.0.0.1:9222
browser-harness -c 'print(page_info())'
```

The `--user-data-dir` MUST NOT be the platform default. Chrome 136+ silently no-ops `--remote-debugging-port` when the default profile path is used.

**Background Xvfb & Keyring Pitfall:** 
Never attempt to clone the user's active/foreground profile (e.g., `Profile 15`) to run it headless via Xvfb for background automation. Chromium encrypts cookies using the OS keyring (GNOME password store). When run in an isolated Xvfb headless session, the browser loses access to the keyring, fails to decrypt cookies, and invalidates authenticated sessions (leading to instant detection and login redirects on strict sites like X/Twitter). Always use the dedicated `hermes-automation` profile where the user logs in once explicitly.

## Error: "DevToolsActivePort not found"

Root cause: Chromium was running but remote debugging was not enabled.

Fix: Open `chrome://inspect/#remote-debugging` and tick the checkbox.

## Error: "Invalid parameters" from switch_tab

Reproduction:
```python
switch_tab(-1)   # raises RuntimeError: Invalid parameters
```

`switch_tab` expects a `targetId` string or a dict like `{"targetId": "..."}`.
It does NOT accept integer indices. To switch to the newest tab after `new_tab`,
use the return value of `new_tab` directly:

```python
tid = new_tab("https://example.com")
# new_tab already calls switch_tab internally, so page_info() works immediately
print(page_info())
```

## Stale daemon cleanup

When `browser-harness --doctor` shows daemon ok but commands still fail:

```bash
browser-harness -c 'restart_daemon()'
```

If that hangs:
```bash
pkill -f browser_harness.daemon
rm -f /tmp/bu-default.sock /tmp/bu-default.pid
```

Then retry the command.

## First-attach popup (Chrome 144+)

On first daemon attach, Chrome may show an in-browser "Allow remote debugging?"
popup. The user must click Allow. This condition is not fully characterized and
may reappear later. Way 2 avoids popups entirely.
