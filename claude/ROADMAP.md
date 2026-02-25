# Claude Code Setup Roadmap

A phased roadmap for building a spec-to-implementation agent orchestration
system using Claude Code, tmux, Docker, ralph loops, and agent teams.

## Vision

Give a product spec -> agent team implements everything autonomously ->
dedicated agents run tests and review code -> human-in-the-loop for all
design decisions -> working software with test coverage.

---

## Phase 0: Foundation

**Goal:** Shell, tmux, and Claude Code wired together.

### Shell Environment (`claude/claude-env.sh`)

Source from `~/.bashrc` or `~/.zshrc`. Key aliases:

| Alias | Command | Purpose |
|-------|---------|---------|
| `c` | `claude` | Quick launch |
| `ct` | `claude-team.sh` | Launch agent team |
| `ralph` | `ralph-loop.sh` | Start ralph loop from spec |
| `cdash` | `claude-dashboard.sh` | Agent monitoring dashboard |
| `claude-multi N` | function | N concurrent Claude panes |
| `claude-worktree B` | function | Worktree + Claude for branch B |

### Settings (`claude/settings-template.json`)

Copy to `~/.claude/settings.json`. Enables:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (agent teams)
- `ENABLE_TOOL_SEARCH=true` (lazy-load MCP tools)
- Ralph Stop Hook, TeammateIdle hook, TaskCompleted hook
- `teammateMode: "auto"` (split panes in tmux, in-process otherwise)

### CLAUDE.md

Project-level config. Keep it minimal. Key rules:
- Always ask user before design decisions
- Break work so teammates don't edit same files
- State lives in repo, not context windows

---

## Phase 1: Tmux Agent Infrastructure

**Goal:** Tmux as the orchestration layer for concurrent agent sessions.

### Keybindings (`tmux/claude-tmux.conf`)

| Key | Action |
|-----|--------|
| `prefix + C` | Claude in split pane |
| `prefix + A` | Claude in new window |
| `prefix + T` | Launch agent team (tmux split-pane mode) |
| `prefix + W` | Team layout: lead + 2 workers + dashboard |
| `prefix + M` | 4-pane grid with concurrent Claude sessions |
| `prefix + S` | Start ralph loop (prompts for spec file) |
| `prefix + G` | Worktree-isolated session (prompts for branch) |
| `prefix + D` | Agent dashboard |

### Agent Team Navigation (built-in to Claude Code)

| Key | Action |
|-----|--------|
| `Shift+Down` | Cycle to next teammate |
| `Shift+Up` | Cycle to previous teammate |
| `Ctrl+T` | Toggle task list |
| `Shift+Tab` | Toggle delegate mode (lead coordinates only) |
| `Enter` | View teammate's session |
| `Escape` | Interrupt teammate's turn |

### Layouts

**Team layout** (`prefix + W`):
```
+------------------+------------------+
|                  |    worker-0      |
|      lead        +------------------+
|  (coordinates)   |    worker-1      |
+------------------+------------------+
|           dashboard                  |
+--------------------------------------+
```

**Multi-session** (`prefix + M`):
```
+------------------+------------------+
|   claude-0       |   claude-1       |
+------------------+------------------+
|   claude-2       |   claude-3       |
+------------------+------------------+
```

---

## Phase 2: Ralph Loops

**Goal:** Autonomous agent iteration with external completion verification.

### What Is a Ralph Loop?

Named after Ralph Wiggum (Geoffrey Huntley, 2025). A bash loop that
re-prompts a fresh Claude instance until external criteria are met.
State lives in the repo (files, git history), not in the context window.

```
┌──────────────────────────────────────────────┐
│               Ralph Loop                     │
│                                              │
│  ┌─────────┐                                 │
│  │  Spec   │──> Fresh Claude instance        │
│  │  (PRD)  │    reads spec + progress.json   │
│  └─────────┘    + git log                    │
│       │                                      │
│       ▼                                      │
│  Observe -> Plan -> Elicit -> Act -> Test    │
│       │                                      │
│       ▼                                      │
│  Stop Hook intercepts exit                   │
│  ├── All tasks done? -> EXIT (allow)         │
│  └── Not done? -> Re-inject prompt (exit 2)  │
│       │                                      │
│       ▼                                      │
│  Fresh context window, loop continues        │
└──────────────────────────────────────────────┘
```

### Why Fresh Context Matters

Standard agent loops suffer from context accumulation: every failed
attempt stays in history, degrading reasoning. The ralph loop sidesteps
this by treating each iteration as a fresh start. Memory persists via:

- `progress.json` / `prd.json` - tracks which items are done
- Git history - `git log` and `git diff` show previous work
- `CLAUDE.md` / `AGENTS.md` - accumulated learnings

### Implementation

**`claude/scripts/ralph-loop.sh`** - Full orchestrator:
- Takes a spec file as input
- Creates tmux session with lead + workers + dashboard
- Lead reads spec, breaks into tasks, asks user for design decisions
- Workers implement in parallel (agent teams or git worktrees)
- Test agent verifies each completion

**`claude/hooks/ralph-stop-hook.sh`** - Stop Hook:
- Intercepts Claude's exit attempt
- Checks for completion promise string (default: `RALPH_DONE`)
- Checks progress file for pending tasks
- Exit code 2 re-injects prompt for fresh iteration
- `RALPH_MAX_ITERS` prevents runaway loops (default: 20)

### Usage

```bash
# From shell
ralph spec.md                        # basic
ralph spec.md --workers 4 --worktree # parallel with worktrees

# From tmux
prefix + S  ->  enter spec file path
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `RALPH_SPEC_FILE` | (required) | Path to spec/PRD |
| `RALPH_PROGRESS_FILE` | `./progress.json` | Task tracking |
| `RALPH_MAX_ITERS` | `20` | Max loop iterations |
| `RALPH_COMPLETION_PROMISE` | `RALPH_DONE` | Output string signaling done |

---

## Phase 3: Agent Teams

**Goal:** Coordinated multi-agent implementation with shared task lists.

### Architecture

| Component | Role |
|-----------|------|
| **Lead** | Coordinates, assigns tasks, synthesizes, asks user |
| **Workers** (2-4) | Implement features in parallel |
| **Test Agent** | Runs tests + linting after each task |
| **Task List** | Shared at `~/.claude/tasks/{team}/` |
| **Mailbox** | Inter-agent messaging |

### Team Launcher (`claude/scripts/claude-team.sh`)

```bash
claude-team.sh --spec spec.md --workers 3 --test-agent --dashboard --worktree
```

Options:
- `--spec FILE` - product spec for the team to implement
- `--workers N` - number of worker agents (default: 3)
- `--test-agent` - add dedicated test/review agent
- `--dashboard` - add monitoring pane
- `--worktree` - git worktree per worker (prevents file conflicts)

### Best Practices

1. **3-5 teammates**, 5-6 tasks each
2. **Activate delegate mode** (`Shift+Tab`) immediately
3. **Require plan approval** for workers before they implement
4. **File ownership**: each worker owns different files
5. **Pre-approve permissions** in settings to reduce prompts
6. **Monitor and steer**: check progress, redirect bad approaches

---

## Phase 4: Human-in-the-Loop

**Goal:** Every design decision goes through the user.

### User Elicitation Skill (`claude/skills/elicit/`)

Before any non-trivial task, Claude asks 2-4 targeted questions:
- Architecture choices (framework, language, patterns)
- Data model design
- API design preferences
- Testing strategy
- Priority order

### When to Elicit

| Situation | Questions |
|-----------|-----------|
| New feature | Scope? User? Edge cases? |
| Bug fix | Repro steps? Expected vs actual? |
| Refactor | Goal? Performance? Readability? |
| Architecture | Monolith vs services? Framework? |
| Ambiguity | Any assumption requiring > 2 guesses |

### Meta-Prompting Pattern

When prompts aren't producing good results:
1. Ask Claude to analyze: "What's unclear about this request?"
2. Ask Claude to rewrite: "Rewrite as a clearer instruction"
3. Ask Claude to identify gaps: "What context am I missing?"
4. Iterate until consistent quality

### Independent Verification (`claude/skills/verify/`)

After implementation, spawn a separate subagent to review:
- Logical correctness
- Missing edge cases
- Security vulnerabilities (OWASP top 10)
- Unnecessary complexity
- Test coverage gaps

Output: verification table with PASS/FAIL/UNCERTAIN per item.

---

## Phase 5: Testing & Quality Gates

**Goal:** Automated quality enforcement through hooks and dedicated agents.

### Test Agent (`claude/scripts/claude-test-agent.sh`)

Standalone agent that continuously:
1. Checks for recent changes
2. Runs test suite (auto-detects: npm/pytest/cargo/make)
3. Runs linters
4. Reviews diffs for security issues
5. Reports findings (never modifies source code)

### Hooks

**TaskCompleted** (`claude/hooks/task-completed.sh`):
- Runs tests before allowing a task to be marked complete
- Exit code 2 blocks completion if tests fail

**TeammateIdle** (`claude/hooks/teammate-idle.sh`):
- Checks for pending tasks when a teammate goes idle
- Exit code 2 makes teammate pick up next task

**Ralph Stop Hook** (`claude/hooks/ralph-stop-hook.sh`):
- Intercepts exit, checks completion promise + progress file
- Exit code 2 re-injects prompt for fresh iteration

---

## Phase 6: Docker Isolation

**Goal:** Safe environment for autonomous/risky operations.

### Container (`claude/docker/Dockerfile`)

- Node.js + Claude Code + git + gh CLI + tmux
- `--dangerously-skip-permissions` safe inside container
- Volume-mount workspace for file access

### Use Cases

- Long-running ralph loops (hours/overnight)
- Exploratory coding with full autonomy
- Web research via fallback tools
- CI reproduction

### Safety: Always use `--network none` for unattended runs

```bash
docker run -it --rm --network none \
  -v $(pwd):/workspace claude-worker
```

---

## Phase 7: Dashboard & Monitoring

**Goal:** Single-pane-of-glass for all agent activity.

### Dashboard (`claude/scripts/claude-dashboard.sh`)

Monitors:
- **Tmux sessions**: which have Claude running, attached status
- **Agent teams**: members, task progress bars
- **Ralph loops**: iteration count, task completion
- **Git worktrees**: branch, uncommitted changes
- **Recent conversations**: last 24h, size

Interactive controls: `[t]` launch team, `[s]` launch ralph loop,
`[r]` refresh, `[q]` quit.

Access: `cdash` alias, `prefix + D`, or from within team layouts.

---

## Phase 8: The Full Pipeline

### Spec -> Implementation -> Tests -> Ship

```
1. Write spec.md (product requirements)
        │
2. ralph spec.md --workers 3 --test-agent --worktree
        │
3. Lead reads spec, asks user design questions
        │
4. Lead creates agent team, assigns tasks
        │
5. Workers implement in parallel (worktree-isolated)
        │
6. Test agent verifies each completed task
        │
7. Stop hook checks: all tasks done? Tests pass?
   ├── No  -> fresh iteration (ralph loop)
   └── Yes -> present results to user
        │
8. User reviews, requests changes or approves
        │
9. Draft PR created for final review
```

### Key Principles

1. **Human decides, agents execute**: all architecture and design
   decisions go through the user
2. **State in repo, not context**: git history and progress files
   are the source of truth, not LLM memory
3. **Fresh context per iteration**: ralph loops prevent context rot
4. **Parallel but isolated**: worktrees prevent file conflicts
5. **Tests gate everything**: hooks enforce quality before completion
6. **Monitor actively**: dashboard provides visibility into all agents

---

## File Inventory

```
claude/
  ROADMAP.md                    # This file
  claude-env.sh                 # Shell aliases and environment
  settings-template.json        # Copy to ~/.claude/settings.json
  scripts/
    ralph-loop.sh               # Ralph loop orchestrator
    claude-team.sh              # Agent team launcher
    claude-test-agent.sh        # Dedicated test/review agent
    claude-dashboard.sh         # Monitoring dashboard
    claude-worktree-session.sh  # Worktree + Claude helper
  skills/
    elicit/SKILL.md             # User elicitation
    verify/SKILL.md             # Independent verification
    spec-implement/SKILL.md     # Full spec-to-implementation pipeline
  hooks/
    ralph-stop-hook.sh          # Ralph loop continuation
    teammate-idle.sh            # Keep teammates working
    task-completed.sh           # Test gate before completion
  docker/
    Dockerfile                  # Isolated Claude container
    docker-compose.yml          # Container orchestration
```
