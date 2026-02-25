#!/usr/bin/env bash
# Claude Code Sandbox Launcher
# Wraps Docker to run Claude Code in an isolated container with:
#   - Domain-allowlist firewall (iptables)
#   - Non-root user
#   - Resource limits
#   - Timeout enforcement
#   - Git credential forwarding
#
# Usage:
#   claude-sandbox.sh [options] [-- claude-args...]
#
# Options:
#   --interactive     Interactive terminal (default)
#   --headless        No terminal, pass prompt via -p
#   --isolated        Minimal network (Claude API only)
#   --no-network      No network at all (cannot call Claude API)
#   --timeout SECS    Kill container after N seconds (default: none)
#   --mount PATH      Bind-mount this directory as /workspace (default: cwd)
#   --extra-domains D Extra domains to allow (space-separated, quoted)
#   --build           Force rebuild the image before running
#   --workers N       Launch N parallel worker containers
#
# Examples:
#   claude-sandbox.sh                         # interactive, firewalled
#   claude-sandbox.sh --isolated              # max isolation
#   claude-sandbox.sh --timeout 3600 -- -p "fix all tests"
#   claude-sandbox.sh --workers 3             # 3 parallel containers
#   claude-sandbox.sh --no-network            # completely offline

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────
MODE="interactive"
TIMEOUT=""
MOUNT_DIR="$(pwd)"
EXTRA_DOMAINS=""
FORCE_BUILD=false
NUM_WORKERS=0
CLAUDE_ARGS=()
COMPOSE_FILE="$(dirname "$(realpath "$0")")/docker-compose.yml"
IMAGE_NAME="claude-sandbox"

# ── Parse args ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interactive)  MODE="interactive"; shift ;;
    --headless)     MODE="headless"; shift ;;
    --isolated)     MODE="isolated"; shift ;;
    --no-network)   MODE="no-network"; shift ;;
    --timeout)      TIMEOUT="$2"; shift 2 ;;
    --mount)        MOUNT_DIR="$(realpath "$2")"; shift 2 ;;
    --extra-domains) EXTRA_DOMAINS="$2"; shift 2 ;;
    --build)        FORCE_BUILD=true; shift ;;
    --workers)      NUM_WORKERS="$2"; shift 2 ;;
    --)             shift; CLAUDE_ARGS=("$@"); break ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      CLAUDE_ARGS+=("$1"); shift ;;
  esac
done

# ── API key check ────────────────────────────────────────────────
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Error: ANTHROPIC_API_KEY is not set."
  echo "Export it or add it to a .env file in the docker directory."
  exit 1
fi

# ── Build if needed ──────────────────────────────────────────────
if [[ "$FORCE_BUILD" == "true" ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "Building Claude sandbox image..."
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$(dirname "$(realpath "$0")")")")"
  docker build -t "$IMAGE_NAME" -f "$(dirname "$(realpath "$0")")/Dockerfile" "$REPO_ROOT"
fi

# ── Git identity forwarding ──────────────────────────────────────
GIT_NAME="${GIT_AUTHOR_NAME:-$(git config user.name 2>/dev/null || true)}"
GIT_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email 2>/dev/null || true)}"

# ── Base docker run args ─────────────────────────────────────────
BASE_ARGS=(
  --rm
  -v "${MOUNT_DIR}:/workspace"
  -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
  -e "GIT_AUTHOR_NAME=${GIT_NAME}"
  -e "GIT_AUTHOR_EMAIL=${GIT_EMAIL}"
  -e "CLAUDE_SANDBOX_EXTRA_DOMAINS=${EXTRA_DOMAINS}"
  --memory=8g
  --cpus=4
  --pids-limit=512
)

[[ -n "$TIMEOUT" ]] && BASE_ARGS+=(-e "CLAUDE_SANDBOX_TIMEOUT=${TIMEOUT}")

# ── Mode-specific args ───────────────────────────────────────────
case "$MODE" in
  interactive)
    BASE_ARGS+=(-it --cap-add=NET_ADMIN --cap-add=NET_RAW)
    ;;
  headless)
    BASE_ARGS+=(--cap-add=NET_ADMIN --cap-add=NET_RAW)
    [[ -z "$TIMEOUT" ]] && BASE_ARGS+=(-e "CLAUDE_SANDBOX_TIMEOUT=3600")
    ;;
  isolated)
    BASE_ARGS+=(-it --cap-add=NET_ADMIN --cap-add=NET_RAW)
    BASE_ARGS+=(-e "CLAUDE_SANDBOX_EXTRA_DOMAINS=")
    [[ -z "$TIMEOUT" ]] && BASE_ARGS+=(-e "CLAUDE_SANDBOX_TIMEOUT=7200")
    ;;
  no-network)
    BASE_ARGS+=(-it --network=none)
    BASE_ARGS+=(-e "CLAUDE_SANDBOX_FIREWALL=false")
    echo "WARNING: --no-network means Claude cannot call the API."
    echo "This mode only works with cached/local models or pre-generated plans."
    ;;
esac

# ── Security hardening ───────────────────────────────────────────
BASE_ARGS+=(
  --cap-drop=ALL
  --security-opt=no-new-privileges:true
  --read-only
  --tmpfs=/tmp:rw,noexec,nosuid,size=2g
  --tmpfs=/home/claude:rw,nosuid,size=1g
)

# ── Multi-worker mode ────────────────────────────────────────────
if [[ $NUM_WORKERS -gt 0 ]]; then
  echo "Launching ${NUM_WORKERS} worker containers..."
  PIDS=()
  for ((i=0; i<NUM_WORKERS; i++)); do
    WORKER_ARGS=("${BASE_ARGS[@]}")
    WORKER_ARGS+=(--name "claude-worker-${i}-$$")
    echo "  Starting worker ${i}..."
    docker run "${WORKER_ARGS[@]}" "$IMAGE_NAME" \
      claude --dangerously-skip-permissions "${CLAUDE_ARGS[@]}" &
    PIDS+=($!)
  done

  echo "Workers running: ${PIDS[*]}"
  echo "Press Ctrl+C to stop all workers."

  # Wait for all workers, cleanup on signal
  trap 'echo "Stopping workers..."; for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done; wait' INT TERM
  for pid in "${PIDS[@]}"; do
    wait "$pid" || true
  done
  exit 0
fi

# ── Single container mode ────────────────────────────────────────
CMD=("claude" "--dangerously-skip-permissions")
if [[ ${#CLAUDE_ARGS[@]} -gt 0 ]]; then
  CMD+=("${CLAUDE_ARGS[@]}")
fi

echo "Claude Sandbox [${MODE}]"
echo "  Workspace: ${MOUNT_DIR}"
echo "  Timeout:   ${TIMEOUT:-none}"
[[ -n "$EXTRA_DOMAINS" ]] && echo "  Extra domains: ${EXTRA_DOMAINS}"
echo ""

exec docker run "${BASE_ARGS[@]}" "$IMAGE_NAME" "${CMD[@]}"
