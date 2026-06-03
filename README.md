# Agent Bulletproof Browser Automation

<a href="https://www.producthunt.com/products/agent-bulletproof-browser?embed=true&amp;utm_source=badge-featured&amp;utm_medium=badge&amp;utm_campaign=badge-agent-bulletproof-browser" target="_blank" rel="noopener noreferrer"><img alt="Agent Bulletproof Browser - The 100% stable, headless browser kit for AI agents | Product Hunt" width="250" height="54" src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1162677&amp;theme=light&amp;t=1780507235096"></a>

An enterprise-grade, autonomous headless browser architecture built for AI agents (Hermes, OpenClaw, Claude Code, etc.). 

Most AI developers struggle with agent-spawned browsers crashing, leaving memory leaks, hanging on downloads, or failing Cloudflare checks. This repository provides a drop-in set of wrapper scripts and a pre-configured AI skill (`SKILL.md`) that makes browser automation **100% stable, scalable, and undetectable.**

## 🤖 Auto-Install via AI Agent (Recommended)

Want to install this without touching the terminal? Just copy and paste this exact prompt to your Hermes, OpenClaw, or other AI agent:

> **"Please install the Agent Bulletproof Browser Automation kit from https://github.com/fenestbuc/agent-bulletproof-browser. Clone it, read the `AGENT_INSTRUCTIONS.md` file in the repository, and follow its steps exactly to deploy it to my system."**

The agent will automatically clone the repo, run the installer, and configure its own skills.
 
## 🌟 Key Features

* **Multi-Agent Concurrency (`flock`):** Safely queues concurrent background execution. If multiple AI subagents or cron jobs trigger browser tasks simultaneously, they wait in line instead of crashing the profile database or stealing tab focus.
* **The "Chain of Death" (`prctl`):** Completely eliminates orphaned browser instances and memory leaks. Using low-level Linux syscalls, the Chromium process is biologically tethered to the bash wrapper. If the agent's script is forcefully murdered (`kill -9`) or OOM-killed, the OS kernel instantly annihilates the background browser.
* **Bot Cloaking:** Uses modern native headless mode (`--headless=new`) combined with standard desktop User-Agent spoofing to bypass Cloudflare, X.com, and LinkedIn WAFs.
* **Hardware & Resource Sandboxing:** 
  * `--disable-dev-shm-usage` prevents out-of-memory crashes on massive DOMs.
  * `--disable-gpu` and `--mute-audio` prevent unstable background Linux driver hangs.
  * `--disk-cache-dir=/dev/null` disables caching entirely, preventing your SSD from bloating with gigabytes of tracking data over time.
* **Headless Downloads:** Explicitly injects a CDP `Browser.setDownloadBehavior` command to override Chromium's default security block on headless downloads.
* **Vision-First AI Skill:** Includes the `SKILL.md` that teaches the AI *how* to use the browser efficiently—banning raw WebSockets, forbidding DOM-selector guessing on obfuscated React sites, and strictly enforcing coordinate-based clicking via screenshots.

## 📦 Installation (Manual)

Run the install script to deploy the wrappers and skills into your agent's directory:

```bash
chmod +x install.sh
./install.sh
```

## 🚀 Usage

### 1. Foreground Login (One-Time Setup per Platform)
Run the foreground script to visually log into platforms (X, LinkedIn, etc.):
```bash
start-agent-browser
```
*Note: This uses `--password-store=basic` so cookies are decrypted cleanly when the profile is later launched headlessly.*

### 2. Background Autonomous Execution
Have your AI agent (or cron job) execute Python `browser-harness` scripts through the master wrapper:

```bash
run-agent-headless "
new_tab('https://example.com')
wait_for_load()
capture_screenshot().save('/tmp/shot.png')
print('Success!')
"
```

## 🧠 Why not Playwright or Puppeteer?
This architecture wraps `browser-harness` to connect directly to the browser via Chrome DevTools Protocol (CDP). It allows agents to share a highly optimized, persistent, pre-authenticated profile without the heavy overhead, constant profile wiping, and detectable bot footprints of typical Playwright instances.

---
*Built autonomously by Hermes for Kubar Labs.*