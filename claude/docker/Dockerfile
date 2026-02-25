# Isolated Claude Code environment with security hardening
# Based on Anthropic's official devcontainer reference implementation.
#
# Profiles:
#   Interactive:  docker compose run --rm claude-interactive
#   Headless:     docker compose run --rm claude-headless -p "prompt here"
#   Isolated:     docker compose run --rm claude-isolated  (no network)
#   Multi-agent:  docker compose up claude-worker-1 claude-worker-2
#
# Build:  docker build -t claude-sandbox -f claude/docker/Dockerfile .
# Run:    docker run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
#           -v $(pwd):/workspace -e ANTHROPIC_API_KEY claude-sandbox

FROM node:22-slim

ARG CLAUDE_CODE_VERSION=latest
ARG TZ=UTC
ENV TZ="$TZ"

# ── System packages ──────────────────────────────────────────────
# Includes bubblewrap for Claude Code's native sandbox on Linux,
# iptables/ipset for the firewall, and standard dev tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    tmux \
    curl \
    wget \
    jq \
    ca-certificates \
    sudo \
    procps \
    # Firewall (iptables allowlist for domain-level network control)
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    socat \
    # Claude Code native sandbox (bubblewrap)
    bubblewrap \
    # GitHub CLI
    gh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Non-root user ────────────────────────────────────────────────
# Running as root inside a container is an unnecessary risk.
# The 'claude' user has sudo access only for the firewall script.
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
  && mkdir -p /home/$USERNAME/.claude /workspace /commandhistory \
  && chown -R $USERNAME:$USERNAME /home/$USERNAME /workspace /commandhistory

# ── Claude Code CLI ──────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# ── Firewall script ──────────────────────────────────────────────
# Allowlist-based firewall: only approved domains are reachable.
# Requires --cap-add=NET_ADMIN --cap-add=NET_RAW at runtime.
COPY claude/docker/init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh \
  && echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
     > /etc/sudoers.d/$USERNAME-firewall \
  && chmod 0440 /etc/sudoers.d/$USERNAME-firewall

# ── Entrypoint ───────────────────────────────────────────────────
COPY claude/docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Workspace ────────────────────────────────────────────────────
WORKDIR /workspace

# Persistent bash history
ENV HISTFILE=/commandhistory/.bash_history
RUN touch /commandhistory/.bash_history

# ── Runtime config ───────────────────────────────────────────────
USER $USERNAME
ENV DEVCONTAINER=true
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV CLAUDE_CONFIG_DIR=/home/claude/.claude

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
