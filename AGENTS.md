# Agent Instructions — Agent Bulletproof Browser

## Stack & Tooling
- Shell: Bash 4+
- Python: 3.8+ (for `browser-guard.py` and JSON helpers)
- Tests: bats-core, shellcheck, shfmt
- CI: GitHub Actions (`.github/workflows/ci.yml`)

## Build / Test Commands

```bash
# Full CI validation (requires bats, shellcheck, shfmt)
make ci

# Run only tests
make test

# Run specific test suites
bats tests/test-core.bats        # legacy regression tests
bats tests/lib/                  # new lib unit tests
bash tests/run-tests.sh          # manual standalone tests

# Lint & format
make lint        # shellcheck
make fmt         # shfmt (check)
make fmt-fix     # shfmt (apply)
```

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `scripts/` | Top-level CLI commands (installed to `~/.local/bin/` via wrappers) |
| `lib/`     | Sourced modules: config, logging, detection, network, locking, cleanup, flags |
| `tests/`   | bats tests, manual bash tests |
| `skills/`  | AI agent skill definitions (SKILL.md + references) |

## Coding Conventions

- **Bash**: `set -euo pipefail` on all executable scripts.
- **Indent**: 4 spaces for `.sh`, 2 for `.bats`.
- **Sourced libs**: end with `true` to avoid `source` returning non-zero under `set -e`.
- **Cross-platform**: Linux flock and macOS mkdir lock fallbacks both tested.
- **Backward compatibility**: CLI signatures (`run-agent-headless '<script>'`, etc.) must never change.
- **New feature rule**: write the bats test first, then the implementation.

## Key Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BH_TIMEOUT` | `300` | Max seconds per task |
| `BH_CDP_PORT` | `9222` | DevTools port |
| `AGENT_SKIP_IF_LOCKED` | `0` | Exit 3 if another task holds lock |
| `AGENT_JSON_LOG` | `0` | Emit ND-JSON events |
| `AGENT_LOG_LEVEL` | `info` | `info` \| `warn` \| `error` |

## Installation Model

`install.sh` copies the repo to `~/.local/share/agent-browser/` and creates lightweight wrapper scripts in `~/.local/bin/`. The wrappers set `AGENT_BROWSER_LIB` so scripts can locate `lib/` regardless of how they are invoked.
