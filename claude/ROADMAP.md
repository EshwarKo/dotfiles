# Claude Code Setup Roadmap

A phased roadmap for building a professional Claude Code development environment.
Synthesized from the [45 Claude Code Tips](https://github.com/ykdojo/claude-code-tips)
and real-world workflows: tmux orchestration, Docker isolation, subagent patterns,
user elicitation, independent plan verification, skill authoring, meta-prompting,
and agent dashboarding.

---

## Phase 0: Foundation (Day 1)

**Goal:** Get Claude Code configured and integrated with existing nvim + tmux setup.

### 0.1 Shell Aliases & Environment

Source `claude/claude-env.sh` from your shell RC file. This gives you:

| Alias | Command | Purpose |
|-------|---------|---------|
| `c` | `claude` | Quick launch |
| `ch` | `claude --chrome` | With browser integration |
| `cr` | `claude -r` | Resume recent conversation |
| `cc` | `claude -c` | Continue last conversation |
| `csk` | `claude --dangerously-skip-permissions` | Containerized use only |

### 0.2 CLAUDE.md

The project-level `CLAUDE.md` at the repo root tells Claude about this dotfiles
project. Keep it short. Add patterns only when you catch yourself repeating
instructions (Tip 30).

### 0.3 Global Settings

Apply to `~/.claude/settings.json`:

```json
{
  "env": {
    "ENABLE_TOOL_SEARCH": "true"
  },
  "permissions": {
    "allow": ["Read(~/.claude)"]
  }
}
```

- `ENABLE_TOOL_SEARCH` lazy-loads MCP tools to save context (Tip 15).
- `Read(~/.claude)` lets clone/half-clone skills access conversation history.

### 0.4 Status Line

Install the custom status line script (Tip 0). Shows model, git branch,
uncommitted files, token usage, and last message:

```
Opus 4.5 | dir | branch (2 uncommitted, synced 5m ago) | ████░░░░░░ 40% of 200k
```

Set up via the dx plugin or manually with the context-bar script.

---

## Phase 1: Tmux Integration (Day 2-3)

**Goal:** Use tmux as the control layer for multi-agent workflows.

### 1.1 Enhanced Tmux Config

The updated `tmux/tmux.conf` adds Claude-specific session management:

- `prefix + C` creates a new Claude Code session in a split pane
- `prefix + S` sends selected text from nvim to Claude
- Named sessions for organized multi-agent work

### 1.2 Cascade Workflow (Tip 14)

Work left-to-right across tmux windows:

```
[voice] [agent-1] [agent-2] [agent-3] [editor]
```

- Leftmost: persistent services (voice transcription, dashboard)
- Middle: Claude Code instances, one per task
- Rightmost: nvim editor for manual review

### 1.3 Tmux as Test Harness (Tip 9)

Use tmux to verify Claude Code's own output:

```bash
tmux new-session -d -s test
tmux send-keys -t test 'claude' Enter
sleep 2
tmux send-keys -t test '/context' Enter
sleep 1
tmux capture-pane -t test -p
```

This pattern enables `git bisect` automation, CI verification, and
interactive testing of CLI tools.

---

## Phase 2: Docker Isolation (Day 4-5)

**Goal:** Run risky or long-running Claude sessions in containers.

### 2.1 Dockerfile

`claude/docker/Dockerfile` sets up an isolated Claude Code environment:

- Node.js + Claude Code CLI installed
- Git, gh CLI, tmux available inside container
- Workspace volume-mounted for file access
- `--dangerously-skip-permissions` safe inside container

### 2.2 Compose Stack

`claude/docker/docker-compose.yml` defines:

- `claude-worker`: isolated Claude Code instance
- `claude-dashboard`: agent monitoring (Phase 6)

### 2.3 Orchestration Pattern (Tip 21)

Local Claude Code controls containerized worker via tmux:

```
Local Claude Code
  -> tmux session
    -> docker exec -it claude-worker bash
      -> claude --dangerously-skip-permissions
```

Your local instance sends prompts via `tmux send-keys` and reads output
via `tmux capture-pane`. All risky operations stay sandboxed.

### 2.4 Use Cases

- **Reddit/web research** via Gemini CLI fallback (Tip 11)
- **System prompt patching** on new Claude Code versions (Tip 15)
- **Exploratory coding** where you want full autonomy
- **CI reproduction** testing GitHub Actions failures locally

---

## Phase 3: User Elicitation & Meta-Prompting (Day 6-7)

**Goal:** Use structured questioning to extract better requirements and improve prompts.

### 3.1 User Elicitation Skill

`claude/skills/elicit/SKILL.md` teaches Claude to ask the right questions
before starting work. Instead of guessing, Claude:

1. Identifies ambiguous requirements
2. Asks 2-4 targeted clarifying questions
3. Confirms understanding before proceeding
4. Documents decisions in a brief spec

This is the "CaptainTechno" pattern: meta-prompting and prompt improvement
through systematic user questioning.

### 3.2 Elicitation Patterns

| Situation | Questions to Ask |
|-----------|-----------------|
| New feature | What's the scope? Who's the user? What are edge cases? |
| Bug fix | Steps to reproduce? Expected vs actual? Environment? |
| Refactor | What's the goal? Performance? Readability? Maintainability? |
| Research | What depth? What format? Who's the audience? |

### 3.3 Meta-Prompting Workflow

When your initial prompt isn't getting good results:

1. Ask Claude to **analyze** your prompt: "What's unclear about this request?"
2. Ask Claude to **rewrite** your prompt: "Rewrite this as a clearer instruction"
3. Ask Claude to **identify gaps**: "What context am I missing that would help?"
4. Iterate until the prompt consistently produces quality output

Put recurring prompt patterns into skills so you don't repeat the process.

---

## Phase 4: Independent Plan Verification (Day 8-9)

**Goal:** Verify plans and output through independent review before execution.

### 4.1 Plan Mode Workflow

1. Enter plan mode (`Shift+Tab` or `/plan`)
2. Have Claude gather context and produce a detailed plan
3. **Review the plan yourself** - check file paths, logic, scope
4. Approve or request changes
5. Execute with confidence

### 4.2 Double-Check Pattern (Tip 28)

After Claude produces output, use this verification prompt:

> "Double check everything. Every single claim. At the end, make a table
> of what you were able to verify, what you couldn't, and confidence level."

### 4.3 Cross-Verification Skill

`claude/skills/verify/SKILL.md` implements independent verification:

1. After a plan or implementation is produced, spawn a **separate subagent**
2. The subagent reviews the plan/code with fresh context
3. It checks for: logical errors, missing edge cases, security issues,
   scope creep, unnecessary complexity
4. Returns a structured verification report

This is the "independent plan verification" concept - a second set of eyes
that isn't biased by the original conversation context.

### 4.4 Test-Driven Verification (Tip 34)

For code changes, write tests first:

1. Write failing tests that define the contract
2. Commit the tests
3. Implement code to pass the tests
4. If tests pass, the verification is built-in

---

## Phase 5: Subagents & Task Orchestration (Day 10-12)

**Goal:** Master Claude Code's native subagent system for parallel work.

### 5.1 Subagent Types

| Type | Use Case | Model |
|------|----------|-------|
| `Explore` | Codebase search, file discovery | Sonnet (default) |
| `Plan` | Architecture design, implementation planning | Sonnet |
| `general-purpose` | Complex multi-step tasks | Sonnet |

### 5.2 Parallel Research Pattern

When analyzing a large codebase or investigating an issue:

```
Main agent spawns:
  -> Subagent 1: "Search for all API endpoints" (background)
  -> Subagent 2: "Analyze test coverage" (background)
  -> Subagent 3: "Check for security patterns" (background)
Main agent continues with other work
  <- Results arrive, main agent synthesizes
```

### 5.3 Background Task Pattern (Tip 36)

- `Ctrl+B` moves a running bash command to background
- Subagents can run in background via `run_in_background: true`
- Use exponential backoff for long-running checks (Tip 17):
  check after 1m, 2m, 4m, 8m...

### 5.4 Cascade + Subagent Strategy

Combine tmux cascade (Phase 1) with subagents:

- **Tmux windows**: separate high-level tasks (different features/bugs)
- **Subagents within each window**: parallel research within a task
- **Background processes**: CI checks, Docker builds, test suites

### 5.5 Handoff Between Agents (Tip 8)

When context gets long:

1. Ask current agent to write `HANDOFF.md`
2. Start fresh conversation
3. Point new agent at `HANDOFF.md`
4. New agent continues with full context but clean token budget

Or use `/half-clone` to keep the recent half of conversation.

---

## Phase 6: Skill Authoring (Day 13-15)

**Goal:** Create custom skills to codify your workflows.

### 6.1 Skill Structure

Skills live in `~/.claude/skills/<name>/SKILL.md` or as plugin skills:

```
~/.claude/skills/
  elicit/SKILL.md        # User elicitation (Phase 3)
  verify/SKILL.md        # Plan verification (Phase 4)
  dashboard/SKILL.md     # Agent monitoring (Phase 7)
  tdd/SKILL.md           # Test-driven development flow
  devops/SKILL.md        # GitHub Actions debugging
```

### 6.2 Skill vs CLAUDE.md Decision

| Put in CLAUDE.md | Put in a Skill |
|------------------|----------------|
| Always relevant | Sometimes relevant |
| Project conventions | Specific workflows |
| Short (< 10 lines) | Longer instructions |
| Every conversation | On-demand only |

### 6.3 Anthropic Skill Creator Pattern

Use Claude Code itself to create skills (the "Un owen" pattern):

1. Describe the workflow you want to automate
2. Ask Claude to create a `SKILL.md` for it
3. Test the skill with `/skill-name`
4. Iterate on the instructions until it works reliably
5. Package into a plugin if you want to share it

### 6.4 Recommended Skills to Build

1. **`/elicit`** - Ask clarifying questions before starting work
2. **`/verify`** - Independent plan/code verification
3. **`/tdd`** - Write tests first, then implement
4. **`/gha`** - Debug GitHub Actions failures (from dx plugin)
5. **`/handoff`** - Create handoff documents for context continuity
6. **`/review`** - Interactive PR review workflow

---

## Phase 7: Agent Dashboard (Day 16-18)

**Goal:** Monitor multiple Claude Code agents from a single view.

### 7.1 Dashboard Script

`claude/scripts/claude-dashboard.sh` provides a tmux-based dashboard:

```
+------------------------------------------+
| CLAUDE AGENT DASHBOARD                   |
+------------------------------------------+
| Agent | Status  | Task          | Tokens |
|-------|---------|---------------|--------|
| w0    | active  | fix auth bug  |   42%  |
| w1    | active  | add tests     |   18%  |
| w2    | idle    | -             |    0%  |
| w3    | done    | PR review     |   67%  |
+------------------------------------------+
| [r]efresh  [k]ill  [a]ttach  [n]ew      |
+------------------------------------------+
```

### 7.2 What It Monitors

- **Active sessions**: which agents are running
- **Token usage**: context consumption per agent
- **Task status**: what each agent is working on
- **Git state**: branch, uncommitted changes per worktree
- **Background jobs**: Docker builds, CI checks

### 7.3 Implementation Approach

The dashboard uses:
- `tmux list-sessions` to find active Claude sessions
- Conversation JSONL files in `~/.claude/projects/` for token data
- `git status` per worktree for repo state
- Simple bash + `watch` for live updates

---

## Phase 8: Advanced Patterns (Ongoing)

### 8.1 Multi-Model Orchestration (Tip 21)

Route tasks to the right model:
- **Opus**: complex reasoning, architecture, difficult bugs
- **Sonnet**: everyday coding, reviews, routine tasks
- **Haiku**: quick lookups, simple edits, status checks

### 8.2 Git Worktrees for Parallel Branches (Tip 16)

```bash
git worktree add ../feature-auth feature/auth
git worktree add ../fix-perf fix/performance
```

Each worktree gets its own tmux window + Claude instance.

### 8.3 Automated Workflow Chains

Combine skills into chains:
1. `/elicit` -> gather requirements
2. `/plan` -> design implementation
3. `/verify` -> independent review of plan
4. Code implementation with TDD
5. `/verify` -> review of implementation
6. PR creation and draft review

### 8.4 Context Management Strategy

| Context Level | Action |
|---------------|--------|
| 0-40% | Normal operation |
| 40-60% | Consider compacting non-essential context |
| 60-80% | Write handoff doc, prepare for fresh session |
| 80%+ | Half-clone or start new conversation |

### 8.5 Continuous Improvement

- Review CLAUDE.md monthly (Tip 30)
- Audit approved commands with `cc-safe` (Tip 33)
- Update skills based on recurring patterns
- Share what works, learn from the community (Tip 42)

---

## Quick Reference: Tip Mapping

| Concept | Related Tips |
|---------|-------------|
| Tmux integration | 9, 14, 17, 21, 36 |
| Docker isolation | 21 |
| User elicitation | 3, 28, 39 |
| Plan verification | 28, 34, 39 |
| Subagents & tasks | 3, 36 |
| Skill authoring | 11, 25, 29, 30 |
| Meta-prompting | 5, 8, 40 |
| Agent dashboard | 0, 14, 21 |
| Context management | 5, 8, 15, 23 |
| Git workflows | 4, 16 |
| Testing & TDD | 9, 34 |
| Voice input | 2 |

---

## File Inventory

```
claude/
  ROADMAP.md              # This file
  claude-env.sh           # Shell aliases and environment
  docker/
    Dockerfile            # Isolated Claude Code container
    docker-compose.yml    # Container orchestration
  skills/
    elicit/SKILL.md       # User elicitation skill
    verify/SKILL.md       # Independent verification skill
  scripts/
    claude-dashboard.sh   # Agent monitoring dashboard
```
