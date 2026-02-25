#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$1"; }
skip()  { printf '\033[1;33m  –\033[0m %s (already done)\n' "$1"; }

# ── Shell aliases ────────────────────────────────────────────────────
setup_shell() {
  local source_line="source ${DOTFILES}/claude/claude-env.sh"
  local rc

  # detect shell rc file
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    rc="$HOME/.zshrc"
  else
    rc="$HOME/.bashrc"
  fi

  info "Shell aliases → $rc"
  if [[ -f "$rc" ]] && grep -qF "claude-env.sh" "$rc" 2>/dev/null; then
    skip "source line in $rc"
  else
    printf '\n# Claude Code dotfiles\n%s\n' "$source_line" >> "$rc"
    ok "added source line to $rc"
  fi
}

# ── Claude Code settings ────────────────────────────────────────────
setup_claude_settings() {
  local src="${DOTFILES}/claude/settings-template.json"
  local dst="$HOME/.claude/settings.json"

  info "Claude Code settings → $dst"
  mkdir -p "$HOME/.claude"

  if [[ -f "$dst" ]]; then
    if diff -q "$src" "$dst" >/dev/null 2>&1; then
      skip "settings.json"
    else
      cp "$dst" "${dst}.bak"
      cp "$src" "$dst"
      ok "updated settings.json (backup at settings.json.bak)"
    fi
  else
    cp "$src" "$dst"
    ok "created settings.json"
  fi
}

# ── Tmux ─────────────────────────────────────────────────────────────
setup_tmux() {
  local src="${DOTFILES}/tmux/tmux.conf"
  local dst="$HOME/.tmux.conf"

  info "Tmux config → $dst"
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    skip "tmux.conf symlink"
  else
    [[ -f "$dst" ]] && cp "$dst" "${dst}.bak"
    ln -sf "$src" "$dst"
    ok "linked tmux.conf"
  fi

  # install TPM if missing
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  if [[ ! -d "$tpm_dir" ]]; then
    info "Installing tmux plugin manager (TPM)"
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir" 2>/dev/null
    ok "TPM installed (run prefix+I inside tmux to install plugins)"
  else
    skip "TPM"
  fi
}

# ── Neovim ───────────────────────────────────────────────────────────
setup_nvim() {
  local src="${DOTFILES}/nvim"
  local dst="$HOME/.config/nvim"

  info "Neovim config → $dst"
  mkdir -p "$HOME/.config"

  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    skip "nvim config symlink"
  else
    [[ -e "$dst" ]] && mv "$dst" "${dst}.bak"
    ln -sf "$src" "$dst"
    ok "linked nvim config"
  fi
}

# ── Docker sandbox image (optional) ─────────────────────────────────
setup_docker() {
  if ! command -v docker &>/dev/null; then
    skip "Docker sandbox (docker not installed)"
    return
  fi

  info "Docker sandbox image"
  if docker image inspect claude-sandbox &>/dev/null 2>&1; then
    skip "claude-sandbox image"
  else
    read -rp "  Build claude-sandbox Docker image? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
      docker build -t claude-sandbox -f "${DOTFILES}/claude/docker/Dockerfile" "$DOTFILES"
      ok "built claude-sandbox image"
    else
      skip "Docker build (skipped by user)"
    fi
  fi
}

# ── Run ──────────────────────────────────────────────────────────────
main() {
  echo ""
  printf '\033[1m  Claude Code Dotfiles Setup\033[0m\n'
  echo ""

  setup_shell
  setup_claude_settings
  setup_tmux
  setup_nvim
  setup_docker

  echo ""
  info "Done! Restart your shell or run:"
  echo "    source ~/.bashrc   # or source ~/.zshrc"
  echo ""
}

main "$@"
