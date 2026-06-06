# Agent Bulletproof Browser Automation

<a href="https://www.producthunt.com/products/agent-bulletproof-browser?embed=true&amp;utm_source=badge-featured&amp;utm_medium=badge&amp;utm_campaign=badge-agent-bulletproof-browser" target="_blank" rel="noopener noreferrer"><img alt="Agent Bulletproof Browser - The 100% stable, headless browser kit for AI agents | Product Hunt" width="250" height="54" src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1162677&amp;theme=light&amp;t=1780507235096"></a>

An enterprise-grade, autonomous headless browser architecture built for AI agents (Hermes, OpenClaw, Claude Code, etc.). Works on **Linux and macOS**.

Most AI developers struggle with agent-spawned browsers crashing, leaving memory leaks, hanging on downloads, or failing Cloudflare checks. This repository provides a drop-in set of wrapper scripts and a pre-configured AI skill (`SKILL.md`) that makes browser automation **100% stable, scalable, and undetectable.**

## 🤖 Auto-Install via AI Agent (Recommended)

Want to install this without touching the terminal? Just copy and paste this exact prompt to your Hermes, OpenClaw, or other AI agent:

> **"Please install the Agent Bulletproof Browser Automation kit from https://github.com/fenestbuc/agent-bulletproof-browser. Clone it, read the `AGENT_INSTRUCTIONS.md` file in the repository, and follow its steps exactly to deploy it to my system."**

The agent will automatically clone the repo, run the installer, and configure its own skills.
 
## 🌟 Key Features

* **Cross-Platform (Linux & macOS):** Native wrappers with graceful fallbacks for `flock`, `timeout`, and the `prctl` Chain of Death. No dependency on GNU coreutils on macOS.
* **Multi-Agent Concurrency (`flock`):** Safely queues concurrent background execution. If multiple AI subagents or cron jobs trigger browser tasks simultaneously, they wait in line instead of crashing the profile database or stealing tab focus.
* **The "Chain of Death" (`prctl`):** Completely eliminates orphaned browser instances and memory leaks. On Linux, uses kernel-level `PR_SET_PDEATHSIG`. On macOS, falls back to a robust PPID-watcher that self-terminates the browser if the parent dies.
* **Bot Cloaking:** Uses modern native headless mode (`--headless=new`) combined with dynamic User-Agent spoofing (reads your actual Chromium version) to bypass Cloudflare, X.com, and LinkedIn WAFs.
* **Hardware & Resource Sandboxing:**
  * `--disable-dev-shm-usage` prevents out-of-memory crashes on massive DOMs.
  * `--disable-gpu` and `--mute-audio` prevent unstable background driver hangs.
  * `--disk-cache-dir=/dev/null` disables caching entirely, preventing your SSD from bloating with gigabytes of tracking data over time.
  * Automatic download garbage-collection removes stale run directories after 7 days.
* **Headless Downloads:** Explicitly injects a CDP `Browser.setDownloadBehavior` command to override Chromium's default security block on headless downloads. Files are saved to an isolated, per-run directory.
* **Vision-First AI Skill:** Includes the `SKILL.md` that teaches the AI *how* to use the browser efficiently—banning raw WebSockets, forbidding DOM-selector guessing on obfuscated React sites, and strictly enforcing coordinate-based clicking via screenshots.
* **Profile Separation:** Foreground login and background automation use **different Chromium profiles** (`agent-automation-fg` vs `agent-automation-bg`). This prevents background tasks from murdering your interactive login session, and vice-versa.

## 📦 Installation (Manual)

Run the install script to deploy the wrappers and skills into your agent's directory:

```bash
chmod +x install.sh
./install.sh
```

## 📋 Changelog & Feature Tracking

See [CHANGELOG.md](./CHANGELOG.md) for a history of updates, fixes, and new features.

## 🚀 Usage

### 1. Foreground Login (One-Time Setup per Platform)
Run the foreground script to visually log into platforms (X, LinkedIn, etc.):
```bash
start-agent-browser
```
*Note: This uses `--password-store=basic` so cookies are decrypted cleanly when the profile is later launched headlessly. It runs in a dedicated **foreground profile** that is never touched by background tasks.*

### 2. Sync Auth State to Background Profile
After logging in, copy your cookies and decrypted session state to the background profile so headless tasks can reuse them:
```bash
agent-cookie-sync
```

### 3. Background Autonomous Execution
Have your AI agent (or cron job) execute Python `browser-harness` scripts through the master wrapper:

```bash
run-agent-headless "
new_tab('https://example.com')
wait_for_load()
capture_screenshot().save('/tmp/shot.png')
print('Success!')
"
```

**Environment options:**
* `BH_TIMEOUT=600` — override the 300s default task timeout
* `BH_CDP_PORT=9223` — override the default DevTools port
* `AGENT_SKIP_IF_LOCKED=1` — exit immediately (code 3) instead of queuing if another task is running
* `AGENT_JSON_LOG=1` — emit newline-delimited JSON events to stdout for machine parsing
* `AGENT_LOG_LEVEL=error` — filter JSON logs: `info` (default) | `warn` | `error`

**Pre-flight check:**
```bash
run-agent-headless --check
```

**Structured logging example (for orchestrators):**
```bash
AGENT_JSON_LOG=1 AGENT_LOG_LEVEL=info run-agent-headless "print('task')" 2>/dev/null | jq -c 'select(.event=="task_complete")'
```

## 🧠 Why not Playwright or Puppeteer?
This architecture wraps `browser-harness` to connect directly to the browser via Chrome DevTools Protocol (CDP). It allows agents to share a highly optimized, persistent, pre-authenticated profile without the heavy overhead, constant profile wiping, and detectable bot footprints of typical Playwright instances.

---
*Built autonomously by Hermes for Kubar Labs.*