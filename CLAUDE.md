# Dotfiles Project

Personal dev environment: nvim, tmux, Claude Code agent orchestration.

## Structure

- `nvim/` - Neovim config (lazy.nvim, LSP, Treesitter, Telescope, gruvbox)
- `tmux/` - Tmux config (Ctrl-A prefix, vim navigation, gruvbox, agent team panes)
- `claude/` - Claude Code orchestration system:
  - `scripts/` - ralph-loop, claude-team, dashboard, test-agent, worktree helper
  - `skills/` - elicit, verify, spec-implement
  - `hooks/` - ralph-stop-hook, teammate-idle, task-completed
  - `docker/` - containerized Claude sessions
  - `settings-template.json` - copy to ~/.claude/settings.json

## Agent Team Conventions

- ALWAYS ask the user before making architecture or design decisions
- Break work so each teammate owns different files (no conflicts)
- 3-5 teammates per team, 5-6 tasks per teammate
- Use `--teammate-mode tmux` for split-pane visibility
- Activate delegate mode (Shift+Tab) so lead coordinates only
- Dedicated test agent verifies each completed task

## Ralph Loop Rules

- State lives in the repo (git, progress files), not in context
- Each loop iteration gets fresh context
- Stop hook checks completion; exit code 2 re-injects prompt
- Set RALPH_MAX_ITERS to prevent runaway loops
- Always run in git-tracked directories

## Conventions

- Gruvbox dark theme across all tools
- Vim-style keybindings (hjkl navigation)
- Configs should be modular and well-commented
- Keep files concise; avoid bloat
