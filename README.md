Current config for
- nvim
- tmux
- claude (Claude Code setup, skills, scripts, Docker isolation)

## Setup

```bash
# Shell aliases for Claude Code
echo 'source ~/dotfiles/claude/claude-env.sh' >> ~/.bashrc

# Tmux config (claude extensions auto-loaded via source-file)
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

# Neovim config
ln -sf ~/dotfiles/nvim ~/.config/nvim
```

See `claude/ROADMAP.md` for the full Claude Code setup roadmap.
