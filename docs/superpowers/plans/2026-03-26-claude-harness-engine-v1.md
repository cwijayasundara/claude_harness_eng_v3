# Claude Harness Engine v1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin scaffold that implements a GAN-inspired Generator-Evaluator architecture with Karpathy ratcheting, agent teams, session chaining, and layered evaluation for autonomous long-running application development.

**Architecture:** All output is static files (Markdown, JavaScript, JSON, shell) organized as a Claude Code plugin under `.claude/`. The scaffold is loaded via `--plugin-dir` and copies itself into target projects via `/scaffold`. No build system, no runtime dependencies beyond Node.js (for hooks).

**Tech Stack:** Claude Code plugin system, Node.js (hooks), Markdown (agents/skills), JSON (config/templates), Bash (init.sh)

**Spec:** `docs/superpowers/specs/2026-03-26-claude-harness-engine-v1-design.md`

---

## File Structure

```
.claude/
├── .claude-plugin/plugin.json           # Plugin manifest
├── commands/scaffold.md                 # /scaffold command
├── settings.json                        # Hooks, permissions, env vars
├── architecture.md                      # Layered architecture rules
├── program.md                           # Karpathy human-agent bridge
│
├── agents/                              # 7 agent definitions
│   ├── planner.md
│   ├── generator.md
│   ├── evaluator.md
│   ├── design-critic.md
│   ├── security-reviewer.md
│   ├── ui-designer.md
│   └── test-engineer.md
│
├── skills/                              # 17 skills total
│   ├── brd/SKILL.md
│   ├── spec/SKILL.md
│   ├── design/SKILL.md
│   ├── implement/SKILL.md
│   ├── evaluate/SKILL.md
│   ├── review/SKILL.md
│   ├── test/SKILL.md
│   ├── deploy/SKILL.md
│   ├── build/SKILL.md
│   ├── auto/SKILL.md
│   ├── fix-issue/SKILL.md
│   ├── refactor/SKILL.md
│   ├── improve/SKILL.md
│   ├── code-gen/SKILL.md
│   ├── architecture/SKILL.md
│   ├── evaluation/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── contract-schema.json
│   │       ├── scoring-rubric.md
│   │       └── playwright-patterns.md
│   └── testing/
│       ├── SKILL.md
│       └── references/
│           ├── playwright.md
│           └── test-data.md
│
├── hooks/                               # 12 hooks
│   ├── scope-directory.js
│   ├── protect-env.js
│   ├── detect-secrets.js
│   ├── lint-on-save.js
│   ├── typecheck.js
│   ├── check-architecture.js
│   ├── check-function-length.js
│   ├── check-file-length.js
│   ├── pre-commit-gate.js
│   ├── sprint-contract-gate.js
│   ├── teammate-idle-check.js
│   └── task-completed.js
│
├── state/                               # State files
│   ├── iteration-log.md
│   ├── learned-rules.md
│   ├── failures.md
│   ├── coverage-baseline.txt
│   └── eval-scores.json
│
└── templates/                           # Generation templates
    ├── sprint-contract.json
    ├── features-template.json
    ├── init-sh.template
    ├── docker-compose.template.yml
    └── playwright.config.template.ts
```

---

## Task 1: Plugin Infrastructure & Config

**Files:**
- Create: `.claude/.claude-plugin/plugin.json`
- Create: `.claude/settings.json`
- Create: `.claude/architecture.md`
- Create: `.claude/program.md`

- [ ] **Step 1: Create plugin manifest**

```json
// .claude/.claude-plugin/plugin.json
{
  "name": "claude-harness-engine",
  "version": "1.0.0",
  "description": "GAN-inspired harness for autonomous long-running application development with Karpathy ratcheting, agent teams, and layered evaluation."
}
```

- [ ] **Step 2: Create settings.json with hooks, permissions, and env vars**

Write `.claude/settings.json` with:
- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set to `"1"`
- `permissions.allow` array with all Bash commands from spec Section 10 (pytest, ruff, mypy, npm, git, gh, docker compose, curl, playwright, etc.)
- `hooks.PostToolUse` with `Edit|Write` matcher triggering all 8 quality/security hooks in order: scope-directory, protect-env, detect-secrets, lint-on-save, typecheck, check-architecture, check-function-length, check-file-length
- `hooks.PostToolUse` with `Bash` matcher triggering: pre-commit-gate, sprint-contract-gate
- `hooks.TaskCompleted` triggering: task-completed
- `hooks.TeammateIdle` triggering: teammate-idle-check
- Timeouts: 5000ms for simple hooks, 15000ms for lint, 30000ms for typecheck/pre-commit

Reference: Spec Section 10 for exact hook list, forge_v2's settings.json for format.

- [ ] **Step 3: Create architecture.md**

Write `.claude/architecture.md` — the layered architecture rules. Content:
- Layer hierarchy: Types → Config → Repository → Service → API → UI
- One-way dependency rule (never import from higher layers)
- Verification commands for each layer
- Cross-cutting concerns (logging, auth, telemetry, error handling)
- Note that layers are customizable via `project-manifest.json` for non-standard stacks

Reference: forge_v2's `architecture.md` for format, but make layer names configurable.

- [ ] **Step 4: Create program.md (Karpathy human-agent bridge)**

Write `.claude/program.md` with these sections:
- **Instructions:** Placeholder for BRD instructions
- **Constraints:** Default constraints (layered architecture, review gate, max retries, no deps without noting, self-heal before revert, never delete learned rules)
- **Stopping Criteria:** All features pass, 3 consecutive failures, architecture violation, coverage below threshold, max iterations
- **Self-Healing Policy:** Table of error categories and fix strategies (all 10 from spec Section 7)
- **Pipeline Status:** Table with phases 1-8 and status columns
- **Current Focus:** Template block with iteration, status, story, phase, coverage, etc.

Reference: forge_v2's program.md for exact format, spec Section 7 for self-healing categories.

- [ ] **Step 5: Commit**

```bash
git add .claude/.claude-plugin/plugin.json .claude/settings.json .claude/architecture.md .claude/program.md
git commit -m "feat: add plugin infrastructure and config files"
```

---

## Task 2: Security Hooks (3 files)

**Files:**
- Create: `.claude/hooks/scope-directory.js`
- Create: `.claude/hooks/protect-env.js`
- Create: `.claude/hooks/detect-secrets.js`

- [ ] **Step 1: Write scope-directory.js**

PostToolUse hook for Edit/Write. Reads `CLAUDE_FILE_PATH` env var. Blocks writes outside project directory (`CLAUDE_PROJECT_DIR`) and `/tmp`. Exit 2 with "BLOCKED: Write outside project directory" message. Allow `.claude/` subdirectories.

Reference: forge_v2's `scope-directory.js` — port directly, same logic.

- [ ] **Step 2: Write protect-env.js**

PostToolUse hook for Edit/Write. Reads file path from stdin (JSON) or `CLAUDE_FILE_PATH`. Regex `/^\.env(\..+)?$/` matches `.env`, `.env.local`, `.env.production` but NOT `.env.example`. Exit 2 with "BLOCKED: Cannot modify {filename} — it contains real secrets."

Reference: forge_v2's `protect-env.js` — port directly.

- [ ] **Step 3: Write detect-secrets.js**

PostToolUse hook for Edit/Write. Scans file content for:
- AWS keys: `AKIA[0-9A-Z]{16}`
- GitHub tokens: `gh[pousr]_`
- Anthropic keys: `sk-ant-`
- OpenAI keys: `sk-[a-zA-Z0-9]{20,}`
- Slack tokens: `xox[baprs]-`
- Private key blocks: `-----BEGIN .* PRIVATE KEY-----`
- Connection strings with passwords
- SSNs: `\d{3}-\d{2}-\d{4}`

Skip: `.md`, `.env.example`, `hooks/`, `evals/`, template files. Redact matched values (show first 10 chars). Exit 2 on match.

Reference: forge_v2's `detect-secrets.js` — port directly.

- [ ] **Step 4: Test hooks manually**

```bash
# Test scope-directory: should block
CLAUDE_FILE_PATH=/etc/passwd node .claude/hooks/scope-directory.js
echo $?  # Expected: 2

# Test scope-directory: should allow
CLAUDE_PROJECT_DIR=$(pwd) CLAUDE_FILE_PATH=$(pwd)/test.py node .claude/hooks/scope-directory.js
echo $?  # Expected: 0
```

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/scope-directory.js .claude/hooks/protect-env.js .claude/hooks/detect-secrets.js
git commit -m "feat: add security hooks (scope-directory, protect-env, detect-secrets)"
```

---

## Task 3: Quality Hooks (5 files)

**Files:**
- Create: `.claude/hooks/lint-on-save.js`
- Create: `.claude/hooks/typecheck.js`
- Create: `.claude/hooks/check-architecture.js`
- Create: `.claude/hooks/check-function-length.js`
- Create: `.claude/hooks/check-file-length.js`

- [ ] **Step 1: Write lint-on-save.js**

PostToolUse hook for Edit/Write. Reads `project-manifest.json` from `CLAUDE_PROJECT_DIR` to determine linter:
- `.py` files + manifest says `"linter": "ruff"` → `uv run ruff check --fix "{file}" && uv run ruff format "{file}"`
- `.ts/.tsx` files + manifest says `"linter": "eslint"` → `npx eslint --fix "{file}"`
- Fallback if no manifest: `.py` → ruff, `.ts/.tsx` → eslint
- Non-fatal: always exit 0. Pipe stdio to suppress output.

- [ ] **Step 2: Write typecheck.js**

PostToolUse hook for Edit/Write. Reads manifest for typechecker:
- `.py` files + `"typechecker": "mypy"` → `uv run mypy "{file}"` (non-blocking, exit 0)
- `.ts/.tsx` files + `"typechecker": "tsc"` → `npx tsc --noEmit` (non-blocking, exit 0)
- Report errors to stderr but never block.

- [ ] **Step 3: Write check-architecture.js**

PostToolUse hook for Edit/Write. Only processes `.py` files. Reads `CLAUDE_FILE_PATH`, determines which layer the file is in (by path: `src/service/`, `src/api/`, `src/repository/`, etc.). Scans file for import statements. Blocks (exit 2) if importing from a higher layer:
- `src/types/` cannot import from `src.config`, `src.repository`, `src.service`, `src.api`
- `src/config/` cannot import from `src.repository`, `src.service`, `src.api`
- `src/repository/` cannot import from `src.service`, `src.api`
- `src/service/` cannot import from `src.api`

Report: line numbers and forbidden imports.

Reference: forge_v2's `check-architecture.js` — port directly.

- [ ] **Step 4: Write check-function-length.js**

PostToolUse hook for Edit/Write. Processes `.py` and `.ts/.tsx` files. Detects function definitions and measures their length.
- Python: track `def`/`async def` by indentation
- TypeScript: track `function` declarations and arrow function assignments by brace depth
- Warn (stderr, exit 0) on functions >50 lines with function name, file, and line number.

Reference: forge_v2's `check-function-length.js` — port directly.

- [ ] **Step 5: Write check-file-length.js**

PostToolUse hook for Edit/Write. Processes `.py` and `.ts/.tsx` files. Count lines.
- Skip: test files, config files, type definition files, migrations
- Warn at 200 lines (stderr, exit 0)
- Block at 300 lines (stderr, exit 2)

Reference: forge_v2's `check-file-length.js` — port directly.

- [ ] **Step 6: Test hooks**

```bash
# Test lint-on-save with a Python file
echo "import os" > /tmp/test_lint.py
CLAUDE_PROJECT_DIR=$(pwd) CLAUDE_FILE_PATH=/tmp/test_lint.py node .claude/hooks/lint-on-save.js
echo $?  # Expected: 0

# Test check-architecture with a violation
echo "from src.api import router" > /tmp/test_arch.py
CLAUDE_PROJECT_DIR=$(pwd) CLAUDE_FILE_PATH=$(pwd)/src/service/test.py node .claude/hooks/check-architecture.js
echo $?  # Expected: 2
```

- [ ] **Step 7: Commit**

```bash
git add .claude/hooks/lint-on-save.js .claude/hooks/typecheck.js .claude/hooks/check-architecture.js .claude/hooks/check-function-length.js .claude/hooks/check-file-length.js
git commit -m "feat: add quality hooks (lint, typecheck, architecture, function/file length)"
```

---

## Task 4: Gate & Team Hooks (4 files)

**Files:**
- Create: `.claude/hooks/pre-commit-gate.js`
- Create: `.claude/hooks/sprint-contract-gate.js`
- Create: `.claude/hooks/teammate-idle-check.js`
- Create: `.claude/hooks/task-completed.js`

- [ ] **Step 1: Write pre-commit-gate.js**

PostToolUse hook for Bash. Only activates on `git commit` commands (check stdin/env for command). Recursively scans all `.py` files in `src/` for upward layer imports (same rules as check-architecture.js but across all files). Exit 2 if any violations found with file:line details. If `src/` doesn't exist, exit 0 silently.

Reference: forge_v2's `pre-commit-gate.js` — port directly.

- [ ] **Step 2: Write sprint-contract-gate.js**

PostToolUse hook for Bash. Only activates on `git commit` commands. Logic:
1. Read `claude-progress.txt` in `CLAUDE_PROJECT_DIR` to get current group
2. If no progress file or no current group → exit 0 (allow, not in /auto loop)
3. Check `sprint-contracts/{group}.json` exists
4. If contract exists, check for `specs/reviews/evaluator-report.md` — scan for "VERDICT: PASS"
5. If verdict is not PASS → exit 2 with "BLOCKED: Sprint contract for group {X} not satisfied. Run /evaluate first."
6. If no contract file → exit 0 (not in sprint-contract workflow)

- [ ] **Step 3: Write teammate-idle-check.js**

TeammateIdle hook. Logic:
1. Read stdin for task completion context
2. For each task marked complete, extract file paths from task description
3. For each source file, check if a corresponding test file exists (e.g., `src/service/foo.py` → `tests/service/test_foo.py`)
4. If tests missing → exit 2 with "Task marked complete but no tests found for {file}. Write tests before going idle."
5. If all tasks have tests → exit 0

- [ ] **Step 4: Write task-completed.js**

TaskCompleted hook. Logic:
1. Scan `src/` for architecture violations (same as pre-commit-gate)
2. Report PASS/FAIL
3. Always remind: "Run /review before marking phase complete."
4. Non-blocking: always exit 0.

Reference: forge_v2's `task-completed.js` — port directly.

- [ ] **Step 5: Test gate hooks**

```bash
# Test sprint-contract-gate: should allow when no progress file exists
echo '{"command": "git commit -m test"}' | CLAUDE_PROJECT_DIR=$(pwd) node .claude/hooks/sprint-contract-gate.js
echo $?  # Expected: 0

# Test pre-commit-gate: should pass when no src/ directory
echo '{"command": "git commit -m test"}' | CLAUDE_PROJECT_DIR=$(pwd) node .claude/hooks/pre-commit-gate.js
echo $?  # Expected: 0

# Test teammate-idle-check: should pass with no task context
echo '{}' | node .claude/hooks/teammate-idle-check.js
echo $?  # Expected: 0
```

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/pre-commit-gate.js .claude/hooks/sprint-contract-gate.js .claude/hooks/teammate-idle-check.js .claude/hooks/task-completed.js
git commit -m "feat: add gate hooks (pre-commit, sprint-contract, teammate-idle, task-completed)"
```

---

## Task 5: Agent Definitions (7 files)

**Files:**
- Create: `.claude/agents/planner.md`
- Create: `.claude/agents/generator.md`
- Create: `.claude/agents/evaluator.md`
- Create: `.claude/agents/design-critic.md`
- Create: `.claude/agents/security-reviewer.md`
- Create: `.claude/agents/ui-designer.md`
- Create: `.claude/agents/test-engineer.md`

Each agent is a Markdown file with YAML frontmatter declaring name, description, and tools. Follow Claude Code agent definition format.

- [ ] **Step 1: Write planner.md**

```yaml
---
name: planner
description: Expands user prompts into BRD, decomposes into stories with dependency graph, designs system architecture, generates feature list and machine-readable schemas.
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---
```

Body: Role description, inputs (BRD or user prompt), outputs (specs/brd/, specs/stories/, specs/design/, features.json), workflow steps, quality gates, gotchas. Reference spec Section 2.1.

- [ ] **Step 2: Write generator.md**

```yaml
---
name: generator
description: Implements code and tests from user stories. Spawns agent teams for parallel execution. Negotiates sprint contracts with evaluator.
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
---
```

Body: Role, key rule (never self-evaluate), agent team spawning instructions, file ownership from component-map.md, quality principles reference, learned-rules injection, code-first-then-tests workflow. Reference spec Section 2.2.

- [ ] **Step 3: Write evaluator.md**

```yaml
---
name: evaluator
description: Skeptical verifier that runs the application and checks sprint contract criteria via API tests, Playwright interaction, and schema validation.
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---
```

Body: Role, key rule (execute every check, never assume, never rationalize), 3-layer verification workflow (API via Bash/curl, Playwright MCP, schema validation), verdict format, features.json update rules. Reference spec Sections 2.3 and 3. Note: Playwright MCP is used via natural language instructions to the Playwright MCP server tools.

- [ ] **Step 4: Write design-critic.md**

```yaml
---
name: design-critic
description: GAN counterpart for frontend quality. Takes screenshots and scores against 4 criteria (design quality, originality, craft, functionality).
tools:
  - Read
  - Write
  - Bash
---
```

Body: Role, 4 scoring criteria with rubric descriptions, scoring scale (1-10), threshold (from manifest), max iterations, critique format (specific, actionable, referencing exact elements). Reference spec Section 2.4.

- [ ] **Step 5: Write security-reviewer.md**

```yaml
---
name: security-reviewer
description: Scans for injection, auth bypass, hardcoded secrets, SSRF, path traversal, and other OWASP top 10 vulnerabilities.
tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
---
```

Body: Role, vulnerability categories, severity levels (BLOCK/WARN/INFO), report format, output to specs/reviews/security-review.md. Reference forge_v2's security-reviewer.md.

- [ ] **Step 6: Write ui-designer.md**

```yaml
---
name: ui-designer
description: Creates self-contained React+Tailwind HTML mockups from stories and API contracts during the design phase.
tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---
```

Body: Role, inputs (specs/stories/, specs/design/api-contracts.md), outputs (specs/design/mockups/), mockup requirements (CDN-based, interactive, realistic data, responsive), quality checklist. Reference forge_v2's ui-designer.md.

- [ ] **Step 7: Write test-engineer.md**

```yaml
---
name: test-engineer
description: Generates test plans, test cases mapped to acceptance criteria, Playwright E2E test files, and test data fixtures.
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---
```

Body: Role, inputs (specs/stories/, source code), outputs (specs/test_artefacts/, e2e/), test strategy (unit → integration → E2E), Playwright patterns (selectors, waits), fixture requirements. Reference forge_v2's test-engineer.md.

- [ ] **Step 8: Verify agent frontmatter**

```bash
# Every agent file should have valid YAML frontmatter with name and description
for agent in .claude/agents/*.md; do
  name=$(grep "^name:" "$agent" | head -1)
  desc=$(grep "^description:" "$agent" | head -1)
  if [ -z "$name" ] || [ -z "$desc" ]; then
    echo "INVALID: $agent missing name or description"
  fi
done
# Expected: no output (all valid)
echo "Agent count: $(ls .claude/agents/*.md | wc -l)"
# Expected: 7
```

- [ ] **Step 9: Commit**

```bash
git add .claude/agents/
git commit -m "feat: add 7 agent definitions (planner, generator, evaluator, design-critic, security-reviewer, ui-designer, test-engineer)"
```

---

## Task 6: Reference Skills (4 skills + references)

**Files:**
- Create: `.claude/skills/code-gen/SKILL.md`
- Create: `.claude/skills/architecture/SKILL.md`
- Create: `.claude/skills/evaluation/SKILL.md`
- Create: `.claude/skills/evaluation/references/contract-schema.json`
- Create: `.claude/skills/evaluation/references/scoring-rubric.md`
- Create: `.claude/skills/evaluation/references/playwright-patterns.md`
- Create: `.claude/skills/testing/SKILL.md`
- Create: `.claude/skills/testing/references/playwright.md`
- Create: `.claude/skills/testing/references/test-data.md`

- [ ] **Step 1: Write code-gen/SKILL.md**

Reference skill (no frontmatter agent binding, no `disable-model-invocation`). Content:
- Six quality principles (from spec Section 15) with enforcement details
- Code patterns: Arrange → Act → Assert, error handling with typed classes, naming conventions
- Testing rules: code first then tests, 100% meaningful coverage, only mock external boundaries, realistic test data
- Parallel execution rules: file ownership, plan approval, teammate messaging
- Gotchas list (from forge_v2's code-gen skill)

Reference: forge_v2's `.claude/skills/code-gen/SKILL.md`.

- [ ] **Step 2: Write architecture/SKILL.md**

Reference skill. Content:
- Layered architecture pattern (Types → Config → Repository → Service → API → UI)
- API patterns: typed schemas, request/response models, error responses
- Folder structure template (parameterized by stack)
- Data modeling: UUIDs, timestamps, soft-delete, enums
- `.env.example` documentation requirements
- Migration strategy

Reference: forge_v2's `.claude/skills/architecture/SKILL.md`.

- [ ] **Step 3: Write evaluation/SKILL.md and references**

NEW reference skill. Content:
- Sprint contract format (JSON schema from spec Section 4)
- Three-layer verification workflow
- Evaluator behavioral rules (execute every check, never rationalize)
- Verdict format

References:
- `contract-schema.json`: JSON Schema for sprint contract format
- `scoring-rubric.md`: Detailed rubric for each of the 4 design criteria (1-10 scale with exemplars for scores 1, 4, 7, 10)
- `playwright-patterns.md`: Selector patterns (getByRole, getByLabel, getByText), assertion patterns (toBeVisible, toHaveText), wait patterns (never waitForTimeout), form interaction patterns

- [ ] **Step 4: Write testing/SKILL.md and references**

Reference skill. Content:
- Test strategy: unit → integration → E2E
- Coverage requirements
- Boundary condition generation from acceptance criteria

References:
- `playwright.md`: Playwright config, browser setup, E2E test patterns
- `test-data.md`: Fixture patterns, realistic data requirements, JSON/PDF fixture templates

Reference: forge_v2's `.claude/skills/testing/SKILL.md` and references.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/code-gen/ .claude/skills/architecture/ .claude/skills/evaluation/ .claude/skills/testing/
git commit -m "feat: add 4 reference skills (code-gen, architecture, evaluation, testing)"
```

---

## Task 7: Core Task Skills — Planning Phase (/brd, /spec, /design)

**Files:**
- Create: `.claude/skills/brd/SKILL.md`
- Create: `.claude/skills/spec/SKILL.md`
- Create: `.claude/skills/design/SKILL.md`

- [ ] **Step 1: Write brd/SKILL.md**

```yaml
---
name: brd
description: Socratic interview to create a Business Requirements Document. First step in the SDLC pipeline.
disable-model-invocation: true
context: fork
agent: planner
---
```

Body: 5-dimension exploration (Why, What, Alternatives, How, Edge Cases + UI Context), codebase analysis for existing projects, output format to `specs/brd/`, feasibility assessment, self-audit. Gate: human approval.

Reference: forge_v2's `/brd` skill for structure.

- [ ] **Step 2: Write spec/SKILL.md**

```yaml
---
name: spec
description: Decompose BRD into epics, stories, dependency graph, and feature list for agent team execution.
disable-model-invocation: true
argument-hint: "[path-to-BRD]"
context: fork
agent: planner
---
```

Body: Steps:
1. Read BRD
2. Decompose into epics → stories → acceptance criteria
3. Assign layer + dependency group
4. Build `dependency-graph.md` with parallel groups
5. **NEW: Generate `features.json`** from acceptance criteria — each criterion maps to 1+ features with testable steps, all `passes: false`
6. Present to human for review

Gate: every story has testable acceptance criteria, layer assignment, group assignment. No circular dependencies. Feature list covers all criteria.

Gotchas: vague criteria, missing layers, circular deps, too many stories per epic.

Reference: forge_v2's `/spec` skill + spec Section 8 for features.json format.

- [ ] **Step 3: Write design/SKILL.md**

```yaml
---
name: design
description: Generate system architecture, machine-readable schemas, and UI mockups. Spawns planner + ui-designer concurrently.
disable-model-invocation: true
context: fork
---
```

Body: Spawns 2 agents concurrently:
- **planner** → system-design.md, api-contracts.md + .schema.json, data-models.md + .schema.json, folder-structure.md, component-map.md, deployment.md
- **ui-designer** → specs/design/mockups/ (reads stories + api-contracts)

Post-completion: verify UI data shapes align with API contracts. Gate: human approval.

NEW artifacts vs forge_v2: `api-contracts.schema.json`, `data-models.schema.json`, `component-map.md`.

Reference: forge_v2's `/design` skill + spec Section 6.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/brd/ .claude/skills/spec/ .claude/skills/design/
git commit -m "feat: add planning phase skills (/brd, /spec, /design)"
```

---

## Task 8: Core Task Skills — Execution Phase (/implement, /evaluate, /review)

**Files:**
- Create: `.claude/skills/implement/SKILL.md`
- Create: `.claude/skills/evaluate/SKILL.md`
- Create: `.claude/skills/review/SKILL.md`

- [ ] **Step 1: Write implement/SKILL.md**

```yaml
---
name: implement
description: Generate production code and tests for a story group using agent teams for parallel execution.
disable-model-invocation: true
argument-hint: "[group-id]"
context: fork
agent: generator
---
```

Body: Steps:
1. Read quality principles from `code-gen/SKILL.md`
2. Read `dependency-graph.md` for execution order
3. Read `component-map.md` for file ownership
4. Read `learned-rules.md` — inject into all prompts
5. For multiple independent stories → create agent team (1 teammate per story, file ownership from component-map)
6. Require plan approval before coding
7. After all teammates complete → run full test suite, lint, types
8. Run code-reviewer on changed files (max 3 retries for BLOCK findings)

Reference: forge_v2's `/implement` skill + spec Section 5.

- [ ] **Step 2: Write evaluate/SKILL.md**

```yaml
---
name: evaluate
description: Run the application and verify sprint contract criteria via API tests, Playwright interaction, and schema validation.
disable-model-invocation: true
argument-hint: "[group-id]"
context: fork
agent: evaluator
---
```

Body: Steps:
1. Read `evaluation/SKILL.md` for patterns
2. Read sprint contract from `sprint-contracts/{group}.json`
3. Read `project-manifest.json` for URLs and health check path
4. Verify Docker stack is healthy (assumes `/auto` started it)
5. For each `api_checks` entry: run curl/httpx via Bash, verify status + body, validate against schema
6. For each `playwright_checks` entry: use Playwright MCP tools to navigate, interact, assert
7. For each `architecture_checks` entry: verify files exist, validate schema
8. Update `features.json` — set `passes`, `last_evaluated`, `failure_reason`, `failure_layer`
9. Write `specs/reviews/evaluator-report.md` with VERDICT: PASS or FAIL + specific failures
10. **Mode behavior:** In Solo mode → no-op. In Lean mode → skip design_checks.

Gotchas: never skip checks, never rationalize failures, use getByRole not CSS, use deterministic waits.

Reference: spec Sections 3 and 4.

- [ ] **Step 3: Write review/SKILL.md**

```yaml
---
name: review
description: Run evaluator and security reviewer concurrently for comprehensive quality gate.
disable-model-invocation: true
argument-hint: "[story-id]"
context: fork
---
```

Body: Spawn 2 agents concurrently via Agent tool:
- **evaluator** → specs/reviews/evaluator-report.md
- **security-reviewer** → specs/reviews/security-review.md

Findings: BLOCK (must fix), WARN (should fix), INFO (optional). BLOCK findings enter self-healing loop (max 3).

**Mode behavior:** In Solo mode → security-reviewer only (no evaluator).

Reference: forge_v2's `/review` skill.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/implement/ .claude/skills/evaluate/ .claude/skills/review/
git commit -m "feat: add execution phase skills (/implement, /evaluate, /review)"
```

---

## Task 9: Core Task Skills — Orchestration (/build, /auto)

**Files:**
- Create: `.claude/skills/build/SKILL.md`
- Create: `.claude/skills/auto/SKILL.md`

- [ ] **Step 1: Write build/SKILL.md**

```yaml
---
name: build
description: Full SDLC pipeline. Runs all phases end-to-end with human gates on phases 1-3.
disable-model-invocation: true
argument-hint: "[path-to-BRD] [--mode full|lean|solo]"
context: fork
---
```

Body: 8-phase pipeline:
1. `/brd` → specs/brd/ [HUMAN APPROVAL]
2. `/spec` → specs/stories/ + features.json [HUMAN APPROVAL]
3. `/design` → specs/design/ + schemas [HUMAN APPROVAL]
4. Initialize state files, run `/auto`
5-8. Autonomous via `/auto`

Read `--mode` flag and pass to `/auto`. Default: full.

Reference: forge_v2's `/build` skill + spec Section 12 for modes.

- [ ] **Step 2: Write auto/SKILL.md — frontmatter + usage + prerequisites + context recovery**

```yaml
---
name: auto
description: Autonomous build loop with Karpathy ratcheting, GAN evaluator, and session chaining. Iterates story groups until all features pass or stopping criteria met.
disable-model-invocation: true
argument-hint: "[--mode full|lean|solo] [--group GROUP_ID]"
context: fork
---
```

Write the top section of the skill: usage examples, prerequisites (specs/stories/ approved, specs/design/ approved, program.md exists), agent delegation note (auto orchestrates but never implements), and the context recovery section (Step 1 of the loop: read program.md, learned-rules.md, claude-progress.txt, features.json, dependency-graph.md).

Reference: forge_v2's `/auto` skill top section.

- [ ] **Step 3: Write auto/SKILL.md — the main loop (steps 2-6)**

Append: group selection, sprint contract negotiation protocol (2-step propose-approve, reference spec Section 4), agent team spawning (reference spec Section 5), and the expanded ratchet gate (6 sub-gates with bash commands for each). Include mode-specific gate table:

| Mode | Gates Run |
|------|-----------|
| Full | 1-6 (all) |
| Lean | 1-5 (skip design critic) |
| Solo | 1-3 (tests + lint + coverage only) |

Reference: spec Section 7 steps 1-5, spec Section 12 for modes.

- [ ] **Step 4: Write auto/SKILL.md — self-healing loop + failure learning**

Append: self-healing section with the 10 error categories table (from spec Section 7), the diagnose → classify → fix → re-gate flow, max 3 retries, revert-as-last-resort policy, and failure-driven learning (rule extraction from failures.md, rule injection into prompts, three improvement horizons).

Reference: forge_v2's `/auto` self-healing section + spec Section 7 self-healing categories.

- [ ] **Step 5: Write auto/SKILL.md — Docker management + GAN loop + session chaining + stopping + gotchas**

Append: Docker stack management (init.sh, health gate, between-groups, teardown), architecture amendment detection (check `specs/design/amendments/`), GAN design loop (frontend groups only, max 5 iterations), session chaining (progress file update format), stopping criteria (OR logic with priority from spec Section 7), and gotchas list.

Reference: spec Section 7 (Docker, stopping, session chaining, progress format).

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/build/ .claude/skills/auto/
git commit -m "feat: add orchestration skills (/build, /auto with Karpathy ratchet + GAN evaluator)"
```

---

## Task 10: Remaining Task Skills (/test, /deploy, /fix-issue, /refactor, /improve)

**Files:**
- Create: `.claude/skills/test/SKILL.md`
- Create: `.claude/skills/deploy/SKILL.md`
- Create: `.claude/skills/fix-issue/SKILL.md`
- Create: `.claude/skills/refactor/SKILL.md`
- Create: `.claude/skills/improve/SKILL.md`

- [ ] **Step 1: Write test/SKILL.md**

```yaml
---
name: test
description: Generate test plan, test cases, test data fixtures, and Playwright E2E tests mapped to acceptance criteria.
disable-model-invocation: true
argument-hint: "[--plan-only | --e2e-only]"
context: fork
agent: test-engineer
---
```

Reference: forge_v2's `/test` skill — port with adjustments for flexible stack (read manifest for test runner).

- [ ] **Step 2: Write deploy/SKILL.md**

```yaml
---
name: deploy
description: Generate Docker Compose stack, Dockerfiles, environment config, and init.sh bootstrap script.
disable-model-invocation: true
argument-hint: "[--up]"
context: fork
agent: planner
---
```

Reference: forge_v2's `/deploy` skill — port with adjustments for flexible stack (read manifest for services).

- [ ] **Step 3: Write fix-issue/SKILL.md**

```yaml
---
name: fix-issue
description: Standard GitHub issue workflow. Branch, reproduce, fix, test, PR.
disable-model-invocation: true
argument-hint: "[#issue-number]"
context: fork
---
```

Reference: forge_v2's `/fix-issue` skill — port directly.

- [ ] **Step 4: Write refactor/SKILL.md**

```yaml
---
name: refactor
description: Refactor existing code for quality, performance, or maintainability. Enforces six quality principles with ratchet gate.
disable-model-invocation: true
argument-hint: "[file-or-module-path]"
context: fork
---
```

Reference: forge_v2's `/refactor` skill — port directly.

- [ ] **Step 5: Write improve/SKILL.md**

```yaml
---
name: improve
description: Enhance existing features through story-driven development with full verification.
disable-model-invocation: true
argument-hint: "[description or story-id]"
context: fork
---
```

Reference: forge_v2's `/improve` skill — port directly.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/test/ .claude/skills/deploy/ .claude/skills/fix-issue/ .claude/skills/refactor/ .claude/skills/improve/
git commit -m "feat: add remaining task skills (/test, /deploy, /fix-issue, /refactor, /improve)"
```

---

## Task 11: Templates & State Files

**Files:**
- Create: `.claude/templates/sprint-contract.json`
- Create: `.claude/templates/features-template.json`
- Create: `.claude/templates/init-sh.template`
- Create: `.claude/templates/docker-compose.template.yml`
- Create: `.claude/templates/playwright.config.template.ts`
- Create: `.claude/state/iteration-log.md`
- Create: `.claude/state/learned-rules.md`
- Create: `.claude/state/failures.md`

- [ ] **Step 1: Write sprint-contract.json template**

Empty sprint contract following the schema from spec Section 4:

```json
{
  "group": "",
  "stories": [],
  "contract": {
    "api_checks": [],
    "playwright_checks": [],
    "design_checks": {
      "pages": [],
      "min_score": 7,
      "criteria": ["design_quality", "originality", "craft", "functionality"]
    },
    "architecture_checks": {
      "files_must_exist": [],
      "schema_validation": true
    }
  }
}
```

- [ ] **Step 2: Write features-template.json**

Empty features array with a commented example entry showing all fields:

```json
[]
```

Plus a `features-template.example.json` with one example entry showing all fields (id, category, story, group, description, steps, passes, last_evaluated, failure_reason, failure_layer).

- [ ] **Step 3: Write init-sh.template**

Parameterized shell script with `{{placeholders}}` that `/deploy` fills in:
- `{{BACKEND_INSTALL}}` — e.g., `cd backend && uv sync && cd ..`
- `{{FRONTEND_INSTALL}}` — e.g., `cd frontend && npm ci && cd ..`
- `{{DOCKER_COMPOSE_CMD}}` — e.g., `docker compose up -d --build`
- `{{HEALTH_CHECK_URLS}}` — e.g., `http://localhost:8000/health http://localhost:3000`

Script structure: install deps, copy .env if needed, start Docker, health checks with retry.

- [ ] **Step 4: Write docker-compose.template.yml**

Parameterized Docker Compose with `{{placeholders}}`:
- Backend service with health check, depends_on, bind mounts
- Frontend service with health check
- Database service (if applicable) with health check, volumes
- Network configuration
- .env_file reference

- [ ] **Step 5: Write playwright.config.template.ts**

Playwright config template:
- baseURL from manifest
- webServer that starts Docker Compose
- chromium project
- retries, timeout
- reporter: html

- [ ] **Step 6: Create empty state files**

```markdown
<!-- .claude/state/iteration-log.md -->
# Iteration Log
<!-- Append-only. Do not edit or delete entries. -->
```

```markdown
<!-- .claude/state/learned-rules.md -->
# Learned Rules
<!-- Monotonic — rules are NEVER deleted. -->
```

```markdown
<!-- .claude/state/failures.md -->
# Failure Log
<!-- Append-only. Used for pattern detection. -->
```

- [ ] **Step 7: Create coverage-baseline and eval-scores.json state files**

```
# .claude/state/coverage-baseline.txt
0
```

The ratchet gate compares coverage after each commit against this baseline. Initialized to 0 so the first commit always passes.

```json
// .claude/state/eval-scores.json
[]
```

The design critic appends scoring records here. Each entry: `{ "group": "C", "iteration": 1, "scores": { "design_quality": 7, "originality": 6, "craft": 8, "functionality": 7 }, "average": 7.0, "timestamp": "..." }`.

- [ ] **Step 8: Commit**

```bash
git add .claude/templates/ .claude/state/
git commit -m "feat: add templates (sprint-contract, features, init.sh, docker-compose, playwright) and state files"
```

---

## Task 12: Scaffold Command

**Files:**
- Create: `.claude/commands/scaffold.md`

- [ ] **Step 1: Write scaffold.md**

This is the `/scaffold` slash command that copies the harness into a target project. Format: Claude Code command file (Markdown with instructions).

Content — the complete scaffold procedure from spec Section 14:
1. Detect plugin source via `$CLAUDE_PLUGIN_DIR`
2. Ask user what they're building (brief description)
3. Ask user for tech stack (offer presets: Python+React, Python+Next.js, Node+React, Custom)
4. Generate `project-manifest.json` from answers
5. Copy `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/state/`, `.claude/templates/`, `.claude/architecture.md`, `.claude/program.md`, `.claude/settings.json` to project's `.claude/`
6. Create `specs/brd/`, `specs/stories/`, `specs/design/mockups/`, `specs/reviews/`, `specs/test_artefacts/`, `sprint-contracts/`, `specs/design/amendments/`
7. Generate `CLAUDE.md` tailored to chosen stack (commands, lint tools, test runners from manifest)
8. Generate `design.md` (architecture reference)
9. Generate `init.sh` from template + manifest values
10. Initialize git with `.gitignore` (exclude .env, node_modules, __pycache__, .coverage, dist, build, *.pyc)
11. Initialize `features.json` as empty array
12. Initialize `claude-progress.txt`: `=== Session 0 ===\ndate: {now}\nmode: full\nnext_action: Run /brd to start`
13. Report: "Installed 7 agents, 17 skills, 12 hooks, 5 templates. Run /brd to start."

- [ ] **Step 2: Verify scaffold references all expected directories and files**

```bash
# Scaffold should reference all agent, skill, hook, template, and state directories
for dir in agents skills hooks state templates; do
  grep -q "$dir" .claude/commands/scaffold.md || echo "MISSING: $dir not referenced in scaffold"
done
# Expected: no output

# Scaffold should reference output directories
for dir in "specs/brd" "specs/stories" "specs/design" "specs/reviews" "sprint-contracts"; do
  grep -q "$dir" .claude/commands/scaffold.md || echo "MISSING: $dir not referenced in scaffold"
done
# Expected: no output
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/scaffold.md
git commit -m "feat: add /scaffold command for project initialization"
```

---

## Task 13: Root Documentation

**Files:**
- Create: `CLAUDE.md`
- Create: `design.md`
- Create: `README.md`

- [ ] **Step 1: Write CLAUDE.md**

Project-level instructions for the harness itself (not for generated projects). Content:
- What this repo is (Claude Code plugin scaffold)
- How to install: `claude --plugin-dir /path/to/this/repo/.claude`
- How to scaffold: `/claude-harness-engine:scaffold`
- List of available commands
- Agent roles table
- Hook enforcement summary
- Link to design spec

- [ ] **Step 2: Write design.md**

Architecture reference document for generated projects (~200-300 lines). This gets copied into target projects by `/scaffold`. Include ONLY:
- System architecture ASCII diagram (from spec Section 1, ~30 lines)
- Karpathy ratchet loop ASCII diagram (from spec Section 7, ~25 lines)
- Agent roles table (7 rows, from spec Section 2)
- Hook execution order table (12 rows, from spec Section 10)
- State files table (from spec Section 1 State Layer)
- Sprint contract format summary (from spec Section 4, ~15 lines)
- Quality principles list (6 items, from spec Section 15)

Do NOT include: cost analysis, execution modes, session chaining details, forge_v2 comparison, source links. Those belong in the spec, not the project reference.

- [ ] **Step 3: Write README.md**

Installation guide, quick start, commands reference, architecture overview. For humans browsing the GitHub repo.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md design.md README.md
git commit -m "docs: add CLAUDE.md, design.md, and README.md"
```

---

## Task 14: Integration Verification

- [ ] **Step 1: Verify file count**

```bash
# Expected: 7 agents, 17 skill dirs, 12 hooks, 5 templates, 3 state files, + config
find .claude/agents -name "*.md" | wc -l      # Expected: 7
find .claude/skills -name "SKILL.md" | wc -l   # Expected: 17
find .claude/hooks -name "*.js" | wc -l        # Expected: 12
find .claude/templates -type f | wc -l          # Expected: 5
find .claude/state -type f | wc -l              # Expected: 3
```

- [ ] **Step 2: Verify settings.json references all hooks**

```bash
# Every hook file should be referenced in settings.json
for hook in .claude/hooks/*.js; do
  name=$(basename "$hook")
  grep -q "$name" .claude/settings.json || echo "MISSING: $name"
done
# Expected: no output (all hooks referenced)
```

- [ ] **Step 3: Verify all skills have valid frontmatter**

```bash
# Every SKILL.md should have ---/--- YAML frontmatter
for skill in $(find .claude/skills -name "SKILL.md"); do
  head -1 "$skill" | grep -q "^---$" || echo "MISSING FRONTMATTER: $skill"
done
```

- [ ] **Step 4: Verify agent references in skills**

```bash
# Every skill that binds an agent should reference an agent that exists
for skill in $(find .claude/skills -name "SKILL.md"); do
  agent=$(grep "^agent:" "$skill" | awk '{print $2}')
  if [ -n "$agent" ] && [ ! -f ".claude/agents/$agent.md" ]; then
    echo "BROKEN REFERENCE: $skill -> $agent"
  fi
done
# Expected: no output
```

- [ ] **Step 5: Final commit if any fixes needed**

```bash
git add -A
git status  # Should show nothing to commit if all is clean
```

---

## Execution Order & Dependencies

```
Task 1  (config)        → foundation, no deps
Task 2  (security hooks) → depends on Task 1 (settings.json)
Task 3  (quality hooks)  → depends on Task 1
Task 4  (gate hooks)     → depends on Task 1
Task 5  (agents)         → soft dep on Task 1 (references settings.json env vars); files are standalone .md
Task 6  (ref skills)     → no deps (standalone .md files)
Task 7  (plan skills)    → depends on Task 5 (agents), Task 6 (ref skills)
Task 8  (exec skills)    → depends on Task 5, Task 6
Task 9  (orch skills)    → depends on Task 7, Task 8
Task 10 (other skills)   → depends on Task 5, Task 6
Task 11 (templates)      → no deps
Task 12 (scaffold)       → depends on all above
Task 13 (docs)           → depends on all above
Task 14 (verification)   → depends on all above
```

**Parallelizable groups:**
- Group A: Tasks 1, 5, 6, 11 (no cross-deps)
- Group B: Tasks 2, 3, 4 (depend on Task 1 only)
- Group C: Tasks 7, 8, 10 (depend on Tasks 5, 6)
- Group D: Task 9 (depends on Group C)
- Group E: Tasks 12, 13, 14 (depend on everything)
