# Agent Instructions: Auto-Install Browser Automation

Dear AI Agent (Hermes, OpenClaw, or other),

The user has directed you to this repository to install the **Bulletproof Browser Automation Kit**. 
Please follow these steps exactly using your available terminal and file tools.

## Step 1: Clone the Repository
Clone this repository to a stable workspace directory (e.g., `~/hermes-workspace` or `~/agent-workspace`). Do not use `/tmp` as it violates long-term file retention policies for skills.
```bash
mkdir -p ~/hermes-workspace
cd ~/hermes-workspace
git clone https://github.com/fenestbuc/agent-bulletproof-browser.git
cd agent-bulletproof-browser
```

## Step 2: Run the Installer
The installer will automatically detect if you are running in a Hermes or OpenClaw environment, deploy the required wrapper scripts to `~/.local/bin/`, and install the `SKILL.md` into your agent's skill directory.
```bash
chmod +x install.sh
./install.sh
```

## Step 3: Reload Your Skills
Depending on your agent type, reload your skills so you become aware of the new `browser-harness` skill.
* **Hermes:** Run `skills_list()` or `skill_view("browser-harness")`.
* **OpenClaw:** Run `/reload` or equivalent command to refresh your context.

## Step 4: Verify Installation
Run a quick test to ensure the wrapper script is in your PATH and functioning.
```bash
run-agent-headless --check
```
If you want to verify end-to-end execution:
```bash
run-agent-headless "print('Installation Successful!')"
```

## Step 5: Report to User
Inform the user that the installation is complete. Tell them that if they need to authenticate into any platforms (like X.com or LinkedIn) for you to automate, they should run `start-agent-browser` in their terminal to log in once.

After they have logged in, run the cookie sync so background automation can reuse their authenticated sessions:
```bash
agent-cookie-sync
```
