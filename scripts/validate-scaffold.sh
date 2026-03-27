#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# validate-scaffold.sh — Level 1: Verify /scaffold produced all expected files
#
# Usage:
#   cd /path/to/scaffolded-project
#   bash /path/to/claude_harness_eng_v1/scripts/validate-scaffold.sh
# =============================================================================

PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS  $1"; ((PASS++)); }
fail() { echo "  FAIL  $1"; ((FAIL++)); }
warn() { echo "  WARN  $1"; ((WARN++)); }

check_file() {
  if [ -f "$1" ]; then pass "$1"; else fail "$1 missing"; fi
}

check_dir() {
  if [ -d "$1" ]; then pass "$1/"; else fail "$1/ missing"; fi
}

check_file_count() {
  local dir="$1" pattern="$2" expected="$3" label="$4"
  local count
  count=$(find "$dir" -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ge "$expected" ]; then
    pass "$label: $count files (>= $expected)"
  else
    fail "$label: $count files (expected >= $expected)"
  fi
}

check_json_field() {
  local file="$1" field="$2" label="$3"
  if [ ! -f "$file" ]; then fail "$label: $file missing"; return; fi
  local value
  value=$(jq -r "$field" "$file" 2>/dev/null)
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    pass "$label: $field = $value"
  else
    fail "$label: $field not set in $file"
  fi
}

echo "============================================"
echo " Scaffold Validation"
echo " Project: $(pwd)"
echo " Date: $(date -Iseconds)"
echo "============================================"
echo ""

# --- 1. Core structure ---
echo "--- Core Structure ---"
check_dir ".claude"
check_dir ".claude/agents"
check_dir ".claude/skills"
check_dir ".claude/hooks"
check_dir ".claude/state"
check_dir ".claude/templates"
check_dir "specs"
check_dir "sprint-contracts"

# --- 2. Agent definitions ---
echo ""
echo "--- Agents (expect 7) ---"
check_file_count ".claude/agents" "*.md" 7 "Agent definitions"
for agent in planner generator evaluator design-critic security-reviewer ui-designer test-engineer; do
  check_file ".claude/agents/$agent.md"
done

# --- 3. Skills ---
echo ""
echo "--- Skills (expect >= 14 directories) ---"
skill_count=$(find .claude/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$skill_count" -ge 14 ]; then
  pass "Skill definitions: $skill_count (>= 14)"
else
  fail "Skill definitions: $skill_count (expected >= 14)"
fi

for skill in auto brd spec design implement evaluate build code-gen; do
  check_file ".claude/skills/$skill/SKILL.md"
done

# --- 4. Hooks ---
echo ""
echo "--- Hooks (expect 12) ---"
check_file_count ".claude/hooks" "*.js" 12 "Hook scripts"
for hook in scope-directory protect-env detect-secrets lint-on-save typecheck \
           check-architecture check-function-length check-file-length \
           pre-commit-gate sprint-contract-gate teammate-idle-check task-completed; do
  check_file ".claude/hooks/$hook.js"
done

# --- 5. Configuration ---
echo ""
echo "--- Configuration ---"
check_file ".claude/settings.json"
check_file ".claude/program.md"
check_file ".claude/architecture.md"
check_file "project-manifest.json"
check_file "CLAUDE.md"
check_file "design.md"
check_file "features.json"
check_file "claude-progress.txt"
check_file "init.sh"

# --- 6. Settings.json structure ---
echo ""
echo "--- Settings Validation ---"
check_json_field ".claude/settings.json" '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "Agent teams env"
check_json_field ".claude/settings.json" '.hooks.PostToolUse[0].hooks | length' "PostToolUse hooks count"

if jq -e '.enabledPlugins' .claude/settings.json >/dev/null 2>&1; then
  pass "Official plugins configured"
  for plugin in code-review commit-commands security-guidance pr-review-toolkit; do
    if jq -e ".enabledPlugins[\"$plugin@claude-plugins-official\"]" .claude/settings.json >/dev/null 2>&1; then
      pass "Plugin: $plugin"
    else
      warn "Plugin: $plugin not enabled (optional)"
    fi
  done
else
  warn "No enabledPlugins block (plugins are optional)"
fi

# --- 7. Manifest structure ---
echo ""
echo "--- Manifest Validation ---"
check_json_field "project-manifest.json" '.stack.backend.framework' "Backend framework"
check_json_field "project-manifest.json" '.execution.default_mode' "Default mode"
check_json_field "project-manifest.json" '.execution.coverage_threshold' "Coverage threshold"

if jq -e '.verification.mode' project-manifest.json >/dev/null 2>&1; then
  check_json_field "project-manifest.json" '.verification.mode' "Verification mode"
  check_json_field "project-manifest.json" '.verification.health_check.url' "Health check URL"
else
  warn "No verification block in manifest (will use docker default)"
fi

# --- 8. Calibration profile ---
echo ""
echo "--- Calibration Profile ---"
if [ -f "calibration-profile.json" ]; then
  check_json_field "calibration-profile.json" '.scoring.threshold' "Scoring threshold"
  check_json_field "calibration-profile.json" '.scoring.per_criterion_minimum' "Per-criterion minimum"
  check_json_field "calibration-profile.json" '.iteration.max_iterations' "Max iterations"
  check_json_field "calibration-profile.json" '.iteration.plateau_window' "Plateau window"
else
  warn "No calibration-profile.json (API-only projects don't need one)"
fi

# --- 9. State files ---
echo ""
echo "--- State Files ---"
check_file ".claude/state/learned-rules.md"
check_file ".claude/state/failures.md"
check_file ".claude/state/iteration-log.md"
check_file ".claude/state/coverage-baseline.txt"

# --- 10. Output directories ---
echo ""
echo "--- Output Directories ---"
for dir in specs/brd specs/stories specs/design specs/reviews sprint-contracts; do
  check_dir "$dir"
done

# --- Summary ---
echo ""
echo "============================================"
echo " Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo " Scaffold is INCOMPLETE. Fix the failures above."
  exit 1
else
  echo ""
  echo " Scaffold is VALID."
  exit 0
fi
