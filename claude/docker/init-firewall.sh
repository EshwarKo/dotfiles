#!/bin/bash
# Allowlist-based firewall for Claude Code containers.
# Based on Anthropic's official devcontainer firewall script.
#
# Only approved domains are reachable. Everything else is blocked.
# Requires: --cap-add=NET_ADMIN --cap-add=NET_RAW
#
# Allowed by default:
#   - api.anthropic.com (Claude API)
#   - github.com + GitHub API (git push/pull)
#   - registry.npmjs.org (npm install)
#   - pypi.org + files.pythonhosted.org (pip install)
#   - sentry.io, statsig.com (Claude telemetry)
#   - localhost, host network, DNS, SSH
#
# Add custom domains via CLAUDE_SANDBOX_EXTRA_DOMAINS env var:
#   CLAUDE_SANDBOX_EXTRA_DOMAINS="api.example.com cdn.example.com"

set -euo pipefail
IFS=$'\n\t'

echo "[firewall] Setting up domain allowlist..."

# ── Preserve Docker DNS ──────────────────────────────────────────
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush all existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# Restore Docker DNS
if [ -n "$DOCKER_DNS_RULES" ]; then
  echo "[firewall] Restoring Docker DNS rules..."
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# ── Baseline: allow DNS, SSH, localhost ──────────────────────────
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ── Build domain allowlist ───────────────────────────────────────
ipset create allowed-domains hash:net

# GitHub IP ranges (CIDR blocks from their API)
echo "[firewall] Fetching GitHub IP ranges..."
gh_ranges=$(curl -sf https://api.github.com/meta || true)
if [ -n "$gh_ranges" ] && echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null 2>&1; then
  while read -r cidr; do
    [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]] || continue
    ipset add allowed-domains "$cidr" 2>/dev/null || true
  done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q 2>/dev/null || echo "$gh_ranges" | jq -r '(.web + .api + .git)[]')
  echo "[firewall] GitHub ranges added."
else
  echo "[firewall] WARNING: Could not fetch GitHub ranges. Git push/pull may not work."
fi

# Core domains required for Claude Code
ALLOWED_DOMAINS=(
  "api.anthropic.com"
  "sentry.io"
  "statsig.anthropic.com"
  "statsig.com"
  "registry.npmjs.org"
  "pypi.org"
  "files.pythonhosted.org"
)

# Extra domains from env var
if [ -n "${CLAUDE_SANDBOX_EXTRA_DOMAINS:-}" ]; then
  read -ra EXTRA_DOMAINS <<< "$CLAUDE_SANDBOX_EXTRA_DOMAINS"
  ALLOWED_DOMAINS+=("${EXTRA_DOMAINS[@]}")
fi

for domain in "${ALLOWED_DOMAINS[@]}"; do
  echo "[firewall] Resolving ${domain}..."
  ips=$(dig +noall +answer A "$domain" 2>/dev/null | awk '$4 == "A" {print $5}') || true
  if [ -z "$ips" ]; then
    echo "[firewall] WARNING: Could not resolve ${domain}"
    continue
  fi
  while read -r ip; do
    [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || continue
    ipset add allowed-domains "$ip" 2>/dev/null || true
  done <<< "$ips"
done

# ── Host network (for Docker <-> host communication) ─────────────
HOST_IP=$(ip route | grep default | cut -d" " -f3 || true)
if [ -n "$HOST_IP" ]; then
  HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
  echo "[firewall] Allowing host network: ${HOST_NETWORK}"
  iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
  iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

# ── Apply default-deny policy ────────────────────────────────────
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow only allowlisted destinations
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Reject everything else (immediate feedback, not silent drop)
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# ── Verification ─────────────────────────────────────────────────
echo "[firewall] Verifying..."
if curl --connect-timeout 3 -s https://example.com >/dev/null 2>&1; then
  echo "[firewall] ERROR: example.com should be blocked but is reachable"
  exit 1
fi
echo "[firewall] Blocked example.com (expected)"

if ! curl --connect-timeout 5 -sf https://api.anthropic.com >/dev/null 2>&1; then
  # Non-fatal: API key might not be set yet
  echo "[firewall] WARNING: api.anthropic.com not reachable (may need API key)"
fi

echo "[firewall] Allowlist firewall active. Only approved domains are reachable."
