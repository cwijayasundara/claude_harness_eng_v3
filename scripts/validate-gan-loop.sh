#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# validate-gan-loop.sh — Level 2: Verify GAN loop + Karpathy ratchet after /auto
#
# Run this AFTER /auto completes (any mode). It checks that the harness
# actually enforced GAN separation, ratchet gates, and learning.
#
# Usage:
#   cd /path/to/scaffolded-project
#   bash /path/to/claude_harness_eng_v1/scripts/validate-gan-loop.sh
# =============================================================================

PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS  $1"; ((PASS++)); }
fail() { echo "  FAIL  $1"; ((FAIL++)); }
warn() { echo "  WARN  $1"; ((WARN++)); }

echo "============================================"
echo " GAN Loop + Ratchet Validation"
echo " Project: $(pwd)"
echo " Date: $(date -Iseconds)"
echo "============================================"
echo ""

# ==========================================================================
# 1. GAN SEPARATION: Sprint contracts were negotiated
# ==========================================================================
echo "--- 1. GAN Separation: Sprint Contracts ---"

contract_count=$(find sprint-contracts -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
if [ "$contract_count" -gt 0 ]; then
  pass "Sprint contracts exist: $contract_count"

  # Check contract structure
  for contract in sprint-contracts/*.json; do
    group=$(jq -r '.group // empty' "$contract" 2>/dev/null)
    if [ -n "$group" ]; then
      api_checks=$(jq '.contract.api_checks | length // 0' "$contract" 2>/dev/null)
      pass "Contract $group: $api_checks API checks defined"
    else
      fail "Contract $contract: missing group field"
    fi
  done
else
  fail "No sprint contracts found (GAN negotiation did not run)"
fi

# ==========================================================================
# 2. GAN SEPARATION: Evaluator produced verdicts
# ==========================================================================
echo ""
echo "--- 2. GAN Separation: Evaluator Verdicts ---"

verdict_count=$(find specs/reviews -name "eval-sprint-*" -o -name "evaluator-report*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$verdict_count" -gt 0 ]; then
  pass "Evaluator reports exist: $verdict_count"
else
  # Solo mode skips evaluator — check mode
  mode=$(jq -r '.execution.default_mode // "full"' project-manifest.json 2>/dev/null)
  if [ "$mode" = "solo" ]; then
    warn "No evaluator reports (Solo mode skips evaluator)"
  else
    fail "No evaluator reports found (evaluator did not run)"
  fi
fi

# Check for structured failure JSONs (only present if failures occurred)
failure_json_count=$(find specs/reviews -name "eval-failures-*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$failure_json_count" -gt 0 ]; then
  pass "Structured failure JSONs: $failure_json_count (self-healing used them)"
else
  warn "No structured failure JSONs (either no failures occurred, or not generated)"
fi

# ==========================================================================
# 3. RATCHET: Features tracked
# ==========================================================================
echo ""
echo "--- 3. Ratchet: Feature Tracking ---"

if [ -f "features.json" ]; then
  total=$(jq 'length' features.json 2>/dev/null || echo 0)
  passing=$(jq '[.[] | select(.passes == true)] | length' features.json 2>/dev/null || echo 0)
  failing=$(jq '[.[] | select(.passes == false)] | length' features.json 2>/dev/null || echo 0)
  unevaluated=$(jq '[.[] | select(.passes == null)] | length' features.json 2>/dev/null || echo 0)

  if [ "$total" -gt 0 ]; then
    pass "Features tracked: $total total, $passing passing, $failing failing, $unevaluated unevaluated"
  else
    fail "features.json exists but is empty"
  fi

  if [ "$passing" -gt 0 ]; then
    pass "At least one feature passes"
  else
    warn "No features passing yet"
  fi
else
  fail "features.json missing"
fi

# ==========================================================================
# 4. RATCHET: Coverage baseline maintained
# ==========================================================================
echo ""
echo "--- 4. Ratchet: Coverage ---"

if [ -f ".claude/state/coverage-baseline.txt" ]; then
  baseline=$(cat .claude/state/coverage-baseline.txt | tr -d '[:space:]')
  if [ -n "$baseline" ] && [ "$baseline" != "0" ]; then
    pass "Coverage baseline: ${baseline}%"

    # Verify current coverage meets baseline
    if [ -f "backend/pyproject.toml" ] || [ -f "backend/setup.py" ]; then
      echo "  INFO  Running pytest to verify coverage..."
      actual_cov=$(cd backend && uv run pytest --cov=src --cov-report=term 2>/dev/null | grep "^TOTAL" | awk '{print $NF}' | tr -d '%' || echo "")
      if [ -n "$actual_cov" ]; then
        if [ "$(echo "$actual_cov >= $baseline" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
          pass "Current coverage ${actual_cov}% >= baseline ${baseline}%"
        else
          fail "Coverage regression: ${actual_cov}% < baseline ${baseline}%"
        fi
      else
        warn "Could not measure current coverage (pytest not available or failed)"
      fi
    fi
  else
    warn "Coverage baseline is 0 or empty (first iteration?)"
  fi
else
  warn "No coverage-baseline.txt (coverage tracking not started)"
fi

# ==========================================================================
# 5. RATCHET: Tests pass
# ==========================================================================
echo ""
echo "--- 5. Ratchet: Tests ---"

test_passed=false

# Python tests
if [ -f "backend/pyproject.toml" ] || [ -f "backend/setup.py" ]; then
  echo "  INFO  Running backend tests..."
  if cd backend && uv run pytest -q 2>/dev/null; then
    pass "Backend tests pass"
    test_passed=true
  else
    fail "Backend tests fail"
  fi
  cd ..
fi

# Node tests
if [ -f "frontend/package.json" ]; then
  echo "  INFO  Running frontend tests..."
  if cd frontend && npm test -- --run 2>/dev/null; then
    pass "Frontend tests pass"
    test_passed=true
  else
    # vitest uses different flags
    if npm test 2>/dev/null; then
      pass "Frontend tests pass"
      test_passed=true
    else
      fail "Frontend tests fail"
    fi
  fi
  cd ..
fi

if [ "$test_passed" = false ]; then
  warn "No test suites found or all failed"
fi

# ==========================================================================
# 6. RATCHET: Architecture clean
# ==========================================================================
echo ""
echo "--- 6. Ratchet: Architecture ---"

arch_violations=0

# Check for upward imports in Python backend
if [ -d "backend/src" ]; then
  # Service layer importing from API layer
  if grep -rn "from.*\.api\." backend/src/service/ 2>/dev/null | grep -v "__pycache__"; then
    fail "Architecture violation: service imports from api layer"
    ((arch_violations++))
  fi
  # Repository layer importing from service or API layer
  if grep -rn "from.*\.service\.\|from.*\.api\." backend/src/repository/ 2>/dev/null | grep -v "__pycache__"; then
    fail "Architecture violation: repository imports from service/api layer"
    ((arch_violations++))
  fi

  if [ "$arch_violations" -eq 0 ]; then
    pass "No upward layer imports detected"
  fi
else
  warn "No backend/src directory found"
fi

# Check file sizes
large_files=$(find backend/src frontend/src -name "*.py" -o -name "*.ts" -o -name "*.tsx" 2>/dev/null | while read f; do
  lines=$(wc -l < "$f")
  if [ "$lines" -gt 300 ]; then echo "$f:$lines"; fi
done)

if [ -n "$large_files" ]; then
  fail "Files exceed 300-line limit:"
  echo "$large_files" | while read f; do echo "        $f"; done
else
  pass "All source files under 300 lines"
fi

# ==========================================================================
# 7. LEARNING: Learned rules accumulated
# ==========================================================================
echo ""
echo "--- 7. Learning System ---"

if [ -f ".claude/state/learned-rules.md" ]; then
  rule_count=$(grep -c "^## Rule" .claude/state/learned-rules.md 2>/dev/null || echo 0)
  if [ "$rule_count" -gt 0 ]; then
    pass "Learned rules extracted: $rule_count"
  else
    warn "No learned rules yet (no repeated failures to learn from — could be good)"
  fi
else
  warn "learned-rules.md missing"
fi

if [ -f ".claude/state/failures.md" ]; then
  failure_entries=$(grep -c "^## " .claude/state/failures.md 2>/dev/null || echo 0)
  if [ "$failure_entries" -gt 0 ]; then
    pass "Failure log entries: $failure_entries (self-healing was triggered)"
  else
    warn "No failure entries (either no failures or not logged)"
  fi
else
  warn "failures.md missing"
fi

# ==========================================================================
# 8. SESSION CHAINING: Progress file maintained
# ==========================================================================
echo ""
echo "--- 8. Session Chaining ---"

if [ -f "claude-progress.txt" ]; then
  session_count=$(grep -c "^=== Session" claude-progress.txt 2>/dev/null || echo 0)
  if [ "$session_count" -gt 0 ]; then
    pass "Session blocks: $session_count"

    # Check last session block has required fields
    last_group=$(grep "current_group:" claude-progress.txt | tail -1 | awk '{print $2}')
    if [ -n "$last_group" ]; then
      pass "Last session tracked group: $last_group"
    fi
  else
    warn "claude-progress.txt exists but has no session blocks"
  fi
else
  warn "claude-progress.txt missing"
fi

# ==========================================================================
# 9. ITERATION LOG: History tracked
# ==========================================================================
echo ""
echo "--- 9. Iteration History ---"

if [ -f ".claude/state/iteration-log.md" ]; then
  iter_count=$(grep -c "^## Iteration\|^### Group" .claude/state/iteration-log.md 2>/dev/null || echo 0)
  if [ "$iter_count" -gt 0 ]; then
    pass "Iteration log entries: $iter_count"
  else
    warn "Iteration log exists but is empty"
  fi
else
  warn "iteration-log.md missing"
fi

# ==========================================================================
# 10. GIT HISTORY: Commits follow harness pattern
# ==========================================================================
echo ""
echo "--- 10. Git History ---"

if git log --oneline -1 >/dev/null 2>&1; then
  commit_count=$(git log --oneline 2>/dev/null | wc -l | tr -d ' ')
  pass "Git commits: $commit_count"

  # Check for feat: commits (harness pattern)
  feat_commits=$(git log --oneline 2>/dev/null | grep -c "^[a-f0-9]* feat:" || echo 0)
  if [ "$feat_commits" -gt 0 ]; then
    pass "Feature commits: $feat_commits (harness commit pattern)"
  else
    warn "No feat: commits found"
  fi
else
  warn "Not a git repository"
fi

# ==========================================================================
# 11. PRODUCTION STANDARDS: Code quality spot checks
# ==========================================================================
echo ""
echo "--- 11. Production Standards ---"

# Check for structured logging (Python)
if [ -d "backend/src" ]; then
  logger_usage=$(grep -rn "logging.getLogger\|logger\." backend/src/ 2>/dev/null | grep -v "__pycache__" | wc -l | tr -d ' ')
  if [ "$logger_usage" -gt 0 ]; then
    pass "Structured logging found: $logger_usage references"
  else
    warn "No logging.getLogger usage found in backend"
  fi

  # Check for bare except
  bare_except=$(grep -rn "except Exception:" backend/src/ 2>/dev/null | grep -v "__pycache__" | grep -v "# re-raise" | wc -l | tr -d ' ')
  if [ "$bare_except" -eq 0 ]; then
    pass "No bare 'except Exception:' in backend"
  else
    warn "Found $bare_except bare 'except Exception:' — check if they re-raise"
  fi

  # Check for hardcoded secrets patterns
  secrets=$(grep -rn "api_key\s*=\s*['\"]sk-\|password\s*=\s*['\"]" backend/src/ 2>/dev/null | grep -v "__pycache__" | wc -l | tr -d ' ')
  if [ "$secrets" -eq 0 ]; then
    pass "No hardcoded secrets detected"
  else
    fail "Potential hardcoded secrets: $secrets occurrences"
  fi
fi

# Check for typed error classes
if [ -d "backend/src" ]; then
  typed_errors=$(grep -rn "class.*Error.*Exception\|class.*Error.*BaseException" backend/src/ 2>/dev/null | grep -v "__pycache__" | wc -l | tr -d ' ')
  if [ "$typed_errors" -gt 0 ]; then
    pass "Typed error classes found: $typed_errors"
  else
    warn "No typed error classes found"
  fi
fi

# ==========================================================================
# Summary
# ==========================================================================
echo ""
echo "============================================"
echo " Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "============================================"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo " GAN loop validation: ISSUES FOUND"
  echo " Review the failures above. The harness may not have"
  echo " enforced all constraints during this run."
  exit 1
elif [ "$WARN" -gt 5 ]; then
  echo " GAN loop validation: PARTIAL"
  echo " No hard failures, but many warnings suggest the harness"
  echo " didn't exercise all paths. Try running in Full or Lean mode."
  exit 0
else
  echo " GAN loop validation: PASSED"
  echo " The harness enforced GAN separation, ratchet gates, and learning."
  exit 0
fi
