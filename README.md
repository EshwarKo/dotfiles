Dev environment config: nvim, tmux, and Claude Code agent orchestration.

- `nvim/` - Neovim (lazy.nvim, LSP, Treesitter, Telescope, gruvbox)
- `tmux/` - Tmux (Ctrl-A prefix, vim nav, agent team panes)
- `claude/` - Agent orchestration: ralph loops, agent teams, dashboard, hooks

## Quick Start

```bash
# 1. Shell aliases (c, ct, ralph, cdash, claude-multi, claude-worktree)
echo 'source ~/dotfiles/claude/claude-env.sh' >> ~/.bashrc

# 2. Claude Code settings (agent teams, hooks, lazy MCP)
cp ~/dotfiles/claude/settings-template.json ~/.claude/settings.json

# 3. Tmux config (claude extensions auto-loaded)
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

# 4. Neovim config
ln -sf ~/dotfiles/nvim ~/.config/nvim
```

## Usage

```bash
# Launch agent team (3 workers + test agent + dashboard)
ct --spec spec.md --workers 3 --test-agent --dashboard

# Ralph loop: autonomous spec implementation
ralph spec.md --workers 4 --worktree

# Dashboard: monitor all agents
cdash

# Concurrent sessions: N Claude panes in tmux
claude-multi 4

# Worktree-isolated Claude session
claude-worktree feature-auth

# Containerized session (Docker, firewalled, full permissions)
csb                                       # interactive
csb-isolated                              # Claude API only, no GitHub/npm
csb-headless -- -p "fix all lint errors"  # scripted, 1h timeout
```

## Tmux Keybindings

| Key | Action |
|-----|--------|
| `Ctrl-A T` | Launch agent team |
| `Ctrl-A S` | Ralph loop from spec |
| `Ctrl-A M` | 4-pane concurrent Claude |
| `Ctrl-A W` | Team layout (lead + workers + dash) |
| `Ctrl-A D` | Agent dashboard |
| `Ctrl-A G` | Worktree-isolated session |

See `claude/ROADMAP.md` for the full setup roadmap.
