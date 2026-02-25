#!/usr/bin/env bash
# Claude Agent Dashboard
# Monitors tmux sessions, agent teams, ralph loops, git worktrees.
# Usage: bash claude-dashboard.sh
# Tmux:  bind D new-window -n 'dashboard' 'bash ~/dotfiles/claude/scripts/claude-dashboard.sh'

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
REFRESH=5

# Colors
B='\033[1m'     # bold
D='\033[2m'     # dim
G='\033[32m'    # green
Y='\033[33m'    # yellow
R='\033[31m'    # red
C='\033[36m'    # cyan
M='\033[35m'    # magenta
W='\033[37m'    # white
X='\033[0m'     # reset

bar() {
  local pct=$1 w=20
  local f=$(( pct * w / 100 ))
  local e=$(( w - f ))
  local col="$G"
  (( pct > 60 )) && col="$Y"
  (( pct > 80 )) && col="$R"
  printf "${col}"
  for ((i=0; i<f; i++)); do printf '█'; done
  for ((i=0; i<e; i++)); do printf '░'; done
  printf "${X} %d%%" "$pct"
}

section() {
  echo -e "${B}${C}  ── $1 ──${X}"
  echo ""
}

check_claude_in_pane() {
  local session="$1" pane_idx="$2"
  local pid
  pid=$(tmux list-panes -t "${session}" -F '#{pane_index} #{pane_pid}' 2>/dev/null | \
    awk -v p="$pane_idx" '$1==p {print $2}')
  [[ -n "$pid" ]] && pgrep -P "$pid" -f "claude" >/dev/null 2>&1 && echo "yes" || echo "no"
}

render() {
  clear
  local now
  now=$(date '+%Y-%m-%d %H:%M:%S')

  echo -e "${B}${C}╔════════════════════════════════════════════════════════════════╗${X}"
  echo -e "${B}${C}║            CLAUDE AGENT DASHBOARD          ${D}${now}${B}${C}  ║${X}"
  echo -e "${B}${C}╚════════════════════════════════════════════════════════════════╝${X}"
  echo ""

  # ── Tmux Sessions ──
  section "TMUX SESSIONS"

  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_activity}|#{session_attached}' 2>/dev/null || true)

  if [[ -z "$sessions" ]]; then
    echo -e "  ${D}No tmux sessions${X}"
  else
    printf "  ${B}%-22s %-8s %-10s %-10s %-10s${X}\n" "Session" "Windows" "Attached" "Claude?" "Active"
    printf "  ${D}%-22s %-8s %-10s %-10s %-10s${X}\n" "───────" "───────" "────────" "───────" "──────"

    while IFS='|' read -r name windows activity attached; do
      local has_claude
      has_claude=$(check_claude_in_pane "$name" "0")
      local att_label="no"
      [[ "$attached" == "1" ]] && att_label="${G}yes${X}"

      local col="$D"
      [[ "$has_claude" == "yes" ]] && col="$G"

      local age=""
      if [[ -n "$activity" ]]; then
        local diff=$(( $(date +%s) - activity ))
        if (( diff < 60 )); then age="${diff}s"
        elif (( diff < 3600 )); then age="$(( diff / 60 ))m"
        else age="$(( diff / 3600 ))h"; fi
      fi

      printf "  ${col}%-22s %-8s %-10b %-10s %-10s${X}\n" \
        "$name" "$windows" "$att_label" "$has_claude" "$age"
    done <<< "$sessions"
  fi
  echo ""

  # ── Agent Teams ──
  section "AGENT TEAMS"

  local team_dir="${CLAUDE_DIR}/teams"
  if [[ -d "$team_dir" ]] && ls "$team_dir"/*/config.json >/dev/null 2>&1; then
    for config in "$team_dir"/*/config.json; do
      local team_name
      team_name=$(basename "$(dirname "$config")")
      local members
      members=$(python3 -c "
import json,sys
try:
  c=json.load(open('$config'))
  for m in c.get('members',[]):
    print(f\"    {m.get('name','?'):20s} type={m.get('agentType','?')}\")
except: pass
" 2>/dev/null || echo "    (could not parse)")
      echo -e "  ${M}Team: ${team_name}${X}"
      echo "$members"

      # Show task list if available
      local task_dir="${CLAUDE_DIR}/tasks/${team_name}"
      if [[ -d "$task_dir" ]]; then
        local pending=0 progress=0 done=0
        for tf in "$task_dir"/*.json; do
          [[ -f "$tf" ]] || continue
          local st
          st=$(python3 -c "import json; print(json.load(open('$tf')).get('status','?'))" 2>/dev/null || echo "?")
          case "$st" in
            pending) pending=$((pending+1)) ;;
            in_progress) progress=$((progress+1)) ;;
            completed) done=$((done+1)) ;;
          esac
        done
        local total=$((pending + progress + done))
        if (( total > 0 )); then
          local pct=$(( done * 100 / total ))
          printf "    Tasks: %d done / %d in-progress / %d pending  " "$done" "$progress" "$pending"
          bar "$pct"
          echo ""
        fi
      fi
      echo ""
    done
  else
    echo -e "  ${D}No active agent teams${X}"
  fi
  echo ""

  # ── Ralph Loops ──
  section "RALPH LOOPS"

  local ralph_dir="${CLAUDE_DIR}/ralph-teams"
  local ralph_found=0
  if [[ -d "$ralph_dir" ]]; then
    for state_file in "$ralph_dir"/*/loop-state.json; do
      [[ -f "$state_file" ]] || continue
      ralph_found=1
      python3 -c "
import json
s=json.load(open('$state_file'))
name=s.get('session','?')
status=s.get('status','?')
loops=s.get('loop_count',0)
total=s.get('tasks_total',0)
done=s.get('tasks_completed',0)
print(f'  {name:24s} status={status}  loops={loops}  tasks={done}/{total}')
" 2>/dev/null || echo "  (parse error: $state_file)"
    done
  fi

  # Check for /tmp ralph iteration files
  local ralph_iters
  ralph_iters=$(ls /tmp/ralph-iter-* 2>/dev/null | wc -l || echo "0")
  if (( ralph_iters > 0 )); then
    ralph_found=1
    echo -e "  ${Y}Active loop processes: ${ralph_iters}${X}"
  fi

  (( ralph_found == 0 )) && echo -e "  ${D}No active ralph loops${X}"
  echo ""

  # ── Git Worktrees ──
  section "GIT WORKTREES"

  local worktrees
  worktrees=$(git worktree list 2>/dev/null || true)
  if [[ -z "$worktrees" ]]; then
    echo -e "  ${D}No worktrees (not in a git repo?)${X}"
  else
    while read -r wt_line; do
      local wt_dir branch
      wt_dir=$(echo "$wt_line" | awk '{print $1}')
      branch=$(git -C "$wt_dir" branch --show-current 2>/dev/null || echo "detached")
      local uncommitted
      uncommitted=$(git -C "$wt_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      local col="$D"
      (( uncommitted > 0 )) && col="$Y"
      printf "  ${col}%-50s %-20s %s uncommitted${X}\n" "$wt_dir" "$branch" "$uncommitted"
    done <<< "$worktrees"
  fi
  echo ""

  # ── Recent Conversations ──
  section "RECENT CONVERSATIONS (24h)"

  local found=0
  if [[ -d "$CLAUDE_DIR/projects" ]]; then
    while IFS= read -r conv; do
      [[ -f "$conv" ]] || continue
      found=1
      local name kb
      name=$(basename "$conv" .jsonl)
      kb=$(( $(wc -c < "$conv" | tr -d ' ') / 1024 ))
      printf "  ${D}%-48s %dKB${X}\n" "${name:0:48}" "$kb"
    done < <(find "$CLAUDE_DIR/projects" -name "*.jsonl" -mtime 0 2>/dev/null | sort -t/ -k8 | tail -8)
  fi
  (( found == 0 )) && echo -e "  ${D}None found${X}"
  echo ""

  # ── Footer ──
  echo -e "${B}${C}────────────────────────────────────────────────────────────────${X}"
  echo -e "  ${D}[q] quit  [r] refresh  [t] launch team  [s] launch ralph loop${X}"
  echo -e "  ${D}Auto-refresh: ${REFRESH}s${X}"
}

# ── Main Loop ──
while true; do
  render
  read -t "$REFRESH" -n 1 key 2>/dev/null || true
  case "${key:-}" in
    q|Q) echo ""; exit 0 ;;
    r|R) continue ;;
    t|T)
      read -rp "  Workers (default 3): " nw
      tmux new-window -n 'team' "bash ~/dotfiles/claude/scripts/claude-team.sh --workers ${nw:-3} --test-agent --dashboard"
      ;;
    s|S)
      read -rp "  Spec file path: " sf
      [[ -n "$sf" ]] && tmux new-window -n 'ralph' "bash ~/dotfiles/claude/scripts/ralph-loop.sh '$sf'"
      ;;
  esac
done
