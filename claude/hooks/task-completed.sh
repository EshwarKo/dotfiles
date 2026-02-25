#!/usr/bin/env bash
# TaskCompleted hook - runs when a task is being marked complete.
# Exit code 2 = prevent completion and send feedback.
# Exit code 0 = allow completion.
#
# Install in ~/.claude/settings.json:
#   "hooks": {
#     "TaskCompleted": [{
#       "hooks": [{
#         "type": "command",
#         "command": "bash ~/dotfiles/claude/hooks/task-completed.sh"
#       }]
#     }]
#   }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Check if tests exist and pass before allowing task completion
TEST_CMD=""

if [[ -f "$REPO_ROOT/package.json" ]]; then
  if grep -q '"test"' "$REPO_ROOT/package.json" 2>/dev/null; then
    TEST_CMD="npm test"
  fi
elif [[ -f "$REPO_ROOT/Makefile" ]] && grep -q '^test:' "$REPO_ROOT/Makefile" 2>/dev/null; then
  TEST_CMD="make test"
elif [[ -f "$REPO_ROOT/pytest.ini" ]] || [[ -f "$REPO_ROOT/setup.cfg" ]] || [[ -f "$REPO_ROOT/pyproject.toml" ]]; then
  TEST_CMD="pytest --tb=short -q"
elif [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
  TEST_CMD="cargo test"
fi

if [[ -n "$TEST_CMD" ]]; then
  echo "Running tests before marking task complete: ${TEST_CMD}"
  if ! (cd "$REPO_ROOT" && eval "$TEST_CMD" 2>&1 | tail -20); then
    echo "Tests failed. Fix the failing tests before marking this task complete."
    exit 2  # Block completion
  fi
fi

exit 0  # Allow completion
