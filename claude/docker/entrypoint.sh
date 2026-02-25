#!/usr/bin/env bash
# Container entrypoint for Claude Code sandbox.
# Initializes the firewall (if NET_ADMIN capability is available),
# configures git, and then exec's into the provided command.
set -euo pipefail

# ── Firewall ─────────────────────────────────────────────────────
# Only attempt firewall setup if we have NET_ADMIN capability.
# Containers run with --network=none skip this entirely.
if [[ "${CLAUDE_SANDBOX_FIREWALL:-true}" == "true" ]]; then
  if capsh --print 2>/dev/null | grep -q "cap_net_admin" 2>/dev/null; then
    echo "[sandbox] Initializing firewall allowlist..."
    sudo /usr/local/bin/init-firewall.sh || {
      echo "[sandbox] WARNING: Firewall setup failed. Continuing without network restrictions."
      echo "[sandbox] Run with --cap-add=NET_ADMIN --cap-add=NET_RAW to enable."
    }
  elif [[ "${CLAUDE_SANDBOX_NETWORK:-}" == "none" ]]; then
    echo "[sandbox] Running with --network=none (no network access)."
  else
    echo "[sandbox] No NET_ADMIN capability. Firewall not active."
    echo "[sandbox] For network isolation, use --cap-add=NET_ADMIN or --network=none."
  fi
fi

# ── Git identity ─────────────────────────────────────────────────
# Forward host git config if mounted or set via env vars.
if [[ -n "${GIT_AUTHOR_NAME:-}" ]]; then
  git config --global user.name "$GIT_AUTHOR_NAME"
fi
if [[ -n "${GIT_AUTHOR_EMAIL:-}" ]]; then
  git config --global user.email "$GIT_AUTHOR_EMAIL"
fi
# Trust the mounted workspace directory
git config --global --add safe.directory /workspace

# ── Timeout enforcement ──────────────────────────────────────────
# CLAUDE_SANDBOX_TIMEOUT (in seconds) kills the container after N seconds.
# Prevents runaway containers from burning API credits overnight.
if [[ -n "${CLAUDE_SANDBOX_TIMEOUT:-}" ]]; then
  echo "[sandbox] Timeout set: ${CLAUDE_SANDBOX_TIMEOUT}s"
  (
    sleep "$CLAUDE_SANDBOX_TIMEOUT"
    echo "[sandbox] TIMEOUT reached (${CLAUDE_SANDBOX_TIMEOUT}s). Shutting down."
    kill -TERM 1 2>/dev/null || true
  ) &
fi

# ── Execute ──────────────────────────────────────────────────────
exec "$@"
