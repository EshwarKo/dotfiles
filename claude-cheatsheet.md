# Claude Code Dotfiles Cheatsheet

## Setup (one-time)

```bash
source ~/dotfiles/claude/claude-env.sh          # load aliases (add to .bashrc)
cp ~/dotfiles/claude/settings-template.json ~/.claude/settings.json
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles/nvim ~/.config/nvim
csb-build                                        # (optional) build Docker image
```

---

## Quick Aliases

| Alias | Expands To | Purpose |
|-------|-----------|---------|
| `c` | `claude` | Launch Claude |
| `cc` | `claude -c` | Continue last conversation |
| `cr` | `claude -r` | Resume |
| `ch` | `claude --chrome` | Chrome mode |
| `c --fs` | `claude --fork-session` | Fork current session |
| `csk` | `claude --dangerously-skip-permissions` | Skip permissions |
| `ct` | `claude-team.sh` | Launch agent team |
| `cta` | `claude-team.sh --test-agent --dashboard` | Team + test + dash |
| `ralph` | `ralph-loop.sh` | Autonomous loop |
| `cdash` | `claude-dashboard.sh` | Dashboard |
| `csb` | `claude-sandbox.sh` | Docker sandbox |
| `rp` | `realpath` | Resolve path |

---

## Agent Teams

```bash
ct --spec spec.md --workers 3 --test-agent --dashboard   # full team
ct --name auth-refactor --workers 2 --worktree            # with worktrees
cta                                                       # quick: test + dash
```

**Flags:** `--name NAME` `--workers N` `--spec FILE` `--lead-prompt P` `--worktree` `--test-agent` `--dashboard`

**Layout:**
```
+----------+-----------+
|          | Worker 1  |
|  Lead    +-----------+
|          | Worker 2  |
|          +-----------+
|          | Worker 3  |
+----------+-----------+
|   Dashboard / Tests  |
+----------------------+
```

---

## Ralph Loop (autonomous spec implementation)

```bash
ralph spec.md                              # basic
ralph spec.md --workers 4 --worktree       # parallel + isolated branches
```

**Flags:** `--workers N` `--worktree`

| Env Variable | Default | Purpose |
|-------------|---------|---------|
| `RALPH_MAX_ITERS` | `20` | Safety cap on iterations |
| `RALPH_COMPLETION_PROMISE` | `RALPH_DONE` | Exit signal string |
| `RALPH_ACTIVE` | _(set automatically)_ | Tells hooks loop is running |

**Loop cycle:** Observe -> Plan -> Elicit -> Act -> Test -> Verify -> Loop

---

## Docker Sandbox

```bash
csb                                          # interactive, firewalled
csb-isolated                                 # Claude API only
csb-headless -- -p "fix all lint errors"     # scripted, no terminal
```

**Flags:** `--interactive` `--headless` `--isolated` `--no-network` `--timeout SECS` `--mount PATH` `--extra-domains "d1 d2"` `--workers N` `--build`

| Limit | Value |
|-------|-------|
| Memory | 8 GB |
| CPUs | 4 |
| PIDs | 512 |
| Tmp | 2 GB |

**Security:** `--cap-drop=ALL`, read-only rootfs, no-new-privileges, iptables firewall. SSH agent forwarded automatically.

---

## Tmux Keybindings

**Prefix:** `Ctrl-A`

| Key | Action |
|-----|--------|
| `Ctrl-H/J/K/L` | Navigate panes (vim-style) |
| `Ctrl-A \|` | Split horizontal |
| `Ctrl-A -` | Split vertical |
| `Ctrl-A T` | Launch agent team |
| `Ctrl-A W` | Team layout (lead + 2 workers + dash) |
| `Ctrl-A M` | 4-pane Claude grid |
| `Ctrl-A D` | Open dashboard |
| `Ctrl-A G` | Create worktree + Claude session |
| `Ctrl-A d` | Detach session |

**Claude Code keys (inside a team):**

| Key | Action |
|-----|--------|
| `Shift+Down/Up` | Cycle between teammates |
| `Shift+Tab` | Toggle delegate mode (lead only) |
| `Ctrl+T` | Toggle task list |

---

## Worktrees & Cleanup

```bash
claude-worktree feature-auth     # create worktree + Claude session
claude-multi 3                   # 3 concurrent Claude panes
claude-clean                     # remove worktrees, kill sessions, clean temp
```

---

## Hooks (automatic, configured in settings.json)

| Hook | Trigger | Behavior |
|------|---------|----------|
| **Ralph Stop** | Claude exits during ralph loop | Re-injects prompt if tasks remain (exit 2) |
| **Teammate Idle** | Teammate goes idle | Assigns next pending task (exit 2) |
| **Task Completed** | Task marked done | Runs test suite; blocks if tests fail (exit 2) |

**Auto-detected test commands:** `npm test` / `make test` / `pytest` / `cargo test`

---

## Agent Roles

| Agent | Mode | Purpose |
|-------|------|---------|
| **test-agent** | Read-only | Runs tests, lints, reviews diffs for security. Never modifies code. |
| **review-agent** | Read-only | PASS/FAIL checklist: correctness, security (OWASP), quality, tests. |

---

## Skills

| Skill | When to Use |
|-------|-------------|
| **elicit** | Before ambiguous tasks. Asks 2-4 targeted questions, then proceeds. |
| **verify** | Independent verification of plans, code, or claims. Outputs APPROVED/NEEDS CHANGES/BLOCKED. |
| **spec-implement** | Full pipeline: spec analysis -> elicit -> decompose -> team -> ralph loop -> integrate. |

---

## Sandbox (built-in, no Docker)

Enabled in `settings.json`. Bash runs inside bubblewrap with:

- **Allowed network:** github.com, api.anthropic.com, npmjs.org, pypi.org
- **Denied reads:** `.env*`, `~/.ssh/`, `~/.aws/`
- **Denied edits:** `~/.bashrc`, `~/.zshrc`, `~/.profile`
- **Excluded from sandbox:** `docker`, `docker-compose`

---

## Key Paths

```
~/.claude/settings.json              Config (from settings-template.json)
~/.claude/tasks/                     Team task lists
~/.claude/ralph-teams/               Ralph loop state
~/dotfiles/claude/claude-env.sh      Aliases + functions
~/dotfiles/claude/scripts/           All scripts
~/dotfiles/claude/skills/            Skill definitions
~/dotfiles/claude/hooks/             Hook scripts
~/dotfiles/claude/agents/            Agent definitions
~/dotfiles/claude/docker/            Sandbox + Dockerfile
```

---

## Quick Start Recipes

```bash
# "I have a spec, build it for me"
ralph spec.md --workers 4 --worktree

# "I want a team for ad-hoc work"
ct --workers 3 --test-agent --dashboard

# "Run Claude with full autonomy, safely"
csb-isolated

# "Parallel feature branches"
claude-worktree feature-a
claude-worktree feature-b

# "See what's running"
cdash

# "Done for the day"
claude-clean
```
