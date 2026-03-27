# Harness Gaps Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 identified gaps in the Claude Harness Engine: verification modes, design-critic calibration, cross-cutting agent team concerns, LLM parsing brittleness, and external API integration patterns.

**Architecture:** All changes are to markdown agent/skill definitions and JSON config templates. No application code. Each task modifies 1-2 files and can be committed independently.

**Tech Stack:** Markdown, JSON

**Spec:** `docs/superpowers/specs/2026-03-27-harness-gaps-fix-design.md`

---

## File Map

### Modified Files

| File | Lines | Changes |
|------|-------|---------|
| `.claude/agents/evaluator.md` (116 lines) | Add health-check retry, verification mode awareness, structured failure JSON | Tasks 1, 6 |
| `.claude/agents/design-critic.md` (155 lines) | Read calibration profile, plateau detection, per-criterion minimum | Task 3 |
| `.claude/agents/generator.md` (107 lines) | Dependency handshake, micro-DAG phased execution, integrator pattern, API integration injection | Tasks 4, 11 |
| `.claude/skills/auto/SKILL.md` (490 lines) | Section 4 phase-aware, Section 6 structured failures, Section 7 app lifecycle modes, Section 9 configurable calibration | Tasks 5, 7, 8, 9 |
| `.claude/skills/code-gen/SKILL.md` (124 lines) | LLM Integration section, External API Integration section, Production Standards section | Tasks 10, 12, 13 |
| `.claude/skills/evaluation/references/scoring-examples.md` | Replace with calibration anchors (score 5, 7, 9) | Task 2 |
| `.claude/commands/scaffold.md` (345 lines) | Add calibration-profile.json generation, verification mode question | Task 15 |

### New Files

| File | Purpose | Task |
|------|---------|------|
| `.claude/skills/code-gen/references/api-integration-patterns.md` | Full templates for wrapper, error taxonomy, retry, fixtures, logging | Task 12 |

---

### Task 1: Add Verification Modes to Evaluator

**Files:**
- Modify: `.claude/agents/evaluator.md:25-31` (Inputs section), `:106-114` (Gotchas section)

- [ ] **Step 1: Add verification mode reading to Inputs section**

In `.claude/agents/evaluator.md`, after line 30 (`- A running application (generator is responsible for starting it before hand-off)`), insert the verification mode instructions. Replace the Inputs section (lines 25-30) with:

```markdown
## Inputs

- Sprint summary from the generator
- Stories in `specs/stories/story-NNN.md` (acceptance criteria are your checklist)
- `features.json` (current pass/fail state)
- `project-manifest.json` → read `verification.mode` to determine how to reach the app:
  - `docker` (default): App runs in Docker. Use configured health-check URL. Read error context from `docker compose logs`.
  - `local`: App runs as local processes. Use configured `backend_url` and `frontend_url`. Read error context from process stdout/stderr.
  - `stub`: Mock server auto-generated from `api-contracts.schema.json`. Layer 1 checks run against stub. Layer 2 skipped if no frontend available.

### Health-Check Retry

Before running ANY Layer 1 or Layer 2 check, verify the app is reachable:

```bash
RETRIES=5
BACKOFF=2
URL=$(jq -r '.verification.health_check.url' project-manifest.json)

for i in $(seq 1 $RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  [ "$STATUS" = "200" ] && break
  echo "Health check attempt $i/$RETRIES failed (status: $STATUS), retrying in ${BACKOFF}s..."
  sleep $BACKOFF
  BACKOFF=$((BACKOFF * 2))
done

[ "$STATUS" != "200" ] && echo "FAIL: App not reachable at $URL after $RETRIES attempts"
```

If health check fails after all retries, return a FAIL verdict with `failure_layer: "docker"` (or `"local"` / `"stub"` depending on mode) and `failure_reason: "App not reachable at {url} after {retries} attempts"`.
```

- [ ] **Step 2: Update Gotchas section for mode awareness**

Replace the "Application not running" gotcha (line 108) with:

```markdown
**Application not running:** Run the health-check retry loop before any checks. If the app is not reachable after all retries, this is a FAIL. Do not attempt to start it yourself — report the failure with the verification mode and URL attempted, and return the sprint to the generator.

**Stub mode limitations:** In `stub` mode, Layer 1 checks validate request/response shapes against the schema but cannot verify business logic (e.g., "does uploading a duplicate return 409?"). Note this limitation in the verdict. Layer 2 (Playwright) is skipped unless a frontend URL is configured separately.

**Local mode error context:** In `local` mode, error context comes from process stdout/stderr captured by the orchestrator, not Docker logs. If no error context is available, note "no process logs captured" in the failure reason.
```

- [ ] **Step 3: Add structured failure JSON output to Verdict section**

After the existing verdict format (line 94), add:

```markdown
### Structured Failure Report

In addition to the prose verdict, write a structured failure JSON to `specs/reviews/eval-failures-NNN.json` for each failing check:

```json
{
  "failure": {
    "layer": "api | playwright | design",
    "gate": "evaluator",
    "check": "POST /api/users -> 201",
    "actual": {
      "status": 500,
      "body": "{\"detail\": \"KeyError: 'email'\"}"
    },
    "stack_trace": "Extracted from Docker logs / process stderr. Include file:line if available.",
    "error_type": "key_error | type_error | import_error | timeout | connection_refused | validation_error | assertion_error",
    "files_likely_involved": ["backend/src/service/user_service.py:45"],
    "prior_attempts": []
  }
}
```

Rules for structured failures:
- `stack_trace`: Extract from Docker logs (`docker compose logs --tail=50`) in docker mode, process stderr in local mode, stub mismatch details in stub mode.
- `error_type`: Classify from the exception name in the stack trace. Use `"unknown"` if not classifiable.
- `files_likely_involved`: Parse file paths from the stack trace. Include line numbers when available.
- `prior_attempts`: Leave empty on first evaluation. The `/auto` orchestrator populates this across self-healing iterations.
```

- [ ] **Step 4: Verify the file is valid markdown**

Run: `cat -n .claude/agents/evaluator.md | head -5 && echo "---" && wc -l .claude/agents/evaluator.md`
Expected: File starts with frontmatter, total ~170-180 lines.

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/evaluator.md
git commit -m "feat(evaluator): add verification modes, health-check retry, structured failure JSON"
```

---

### Task 2: Update Scoring Examples with Calibration Anchors

**Files:**
- Modify: `.claude/skills/evaluation/references/scoring-examples.md`

- [ ] **Step 1: Read current scoring-examples.md**

Run: `cat -n .claude/skills/evaluation/references/scoring-examples.md`

Note the current content structure.

- [ ] **Step 2: Replace with calibration anchors**

Overwrite `.claude/skills/evaluation/references/scoring-examples.md` with:

```markdown
# Design Scoring Calibration Examples

Read these examples BEFORE scoring any page. They anchor your scoring to consistent standards.

## Score 5 — Below Threshold (Generic Template)

**Characteristics:**
- Default framework colors (Tailwind gray-50 backgrounds, blue-500 buttons) with no customization
- Stock spacing — default padding/margin from utility classes, no intentional hierarchy
- No typography pairing — single font family, no size variation beyond h1/h2/p defaults
- Generic icons from default icon pack with no sizing or color coordination
- Layout is a single-column stack or basic sidebar — no grid sophistication

**Why it scores 5:**
- Design Quality: 5 — Works but looks like `npx create-next-app` with content added
- Originality: 4 — Zero custom decisions; every element is a library default
- Craft: 5 — Spacing is consistent (framework handles it) but not intentional
- Functionality: 6 — Usable, clear labels, but no affordance refinement
- Weighted: (7.5 + 6.0 + 3.75 + 4.5) / 4.5 = **4.8**

## Score 7 — Threshold Pass (Cohesive Design)

**Characteristics:**
- Custom color palette — 2-3 intentional brand colors, not framework defaults
- Spacing hierarchy — clear visual grouping with larger gaps between sections, tighter within
- Typography pairing — heading font differs from body, or clear size/weight scale (e.g., 32/24/18/14)
- Custom component styling — buttons, cards, inputs have border-radius, shadow, and color that feel coordinated
- Layout uses grid or intentional asymmetry — not just stacked blocks

**Why it scores 7:**
- Design Quality: 7 — Cohesive visual identity; you can tell someone made design decisions
- Originality: 7 — Custom palette and component styling distinguish it from templates
- Craft: 7 — Intentional spacing scale, consistent shadows, aligned elements
- Functionality: 7 — Clear action hierarchy, good feedback on interactions
- Weighted: (10.5 + 10.5 + 5.25 + 5.25) / 4.5 = **7.0**

## Score 9 — Excellent (Distinctive & Crafted)

**Characteristics:**
- Distinctive visual identity — memorable color scheme, unique layout patterns, brand personality
- Micro-interactions — hover states with transitions, loading skeletons, smooth page transitions
- Typography mastery — font pairing that creates mood (e.g., geometric sans for headings + humanist for body)
- Systematic spacing — 4px or 8px base grid visible in all measurements
- Responsive sophistication — not just "mobile works" but layout genuinely adapts (e.g., sidebar becomes bottom nav, grid reflows meaningfully)
- Consistent visual language — every page feels like the same product

**Why it scores 9:**
- Design Quality: 9 — Could be a shipped product; distinctive visual identity
- Originality: 9 — Unique design language; not recognizable as any template
- Craft: 9 — Pixel-level attention to spacing, alignment, color harmony
- Functionality: 8 — Intuitive flows, clear feedback, good error states
- Weighted: (13.5 + 13.5 + 6.75 + 6.0) / 4.5 = **8.8**

## How to Use These Anchors

1. Before scoring, recall the score-5, score-7, and score-9 examples
2. Place the page you are scoring relative to these anchors
3. A page that looks better than score-5 but not as cohesive as score-7 is a 6
4. A page between score-7 and score-9 is an 8
5. Score each criterion independently — a page can have score-8 craft but score-5 originality
```

- [ ] **Step 3: Verify the file**

Run: `wc -l .claude/skills/evaluation/references/scoring-examples.md`
Expected: ~65-75 lines.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/evaluation/references/scoring-examples.md
git commit -m "feat(evaluation): replace scoring examples with calibration anchors (score 5/7/9)"
```

---

### Task 3: Add Calibration Profile to Design-Critic

**Files:**
- Modify: `.claude/agents/design-critic.md:18` (calibration reference), `:61-73` (scoring weights), `:75-83` (threshold + iteration limit)

- [ ] **Step 1: Add calibration profile reading at the top of the Role section**

Replace line 18 in `.claude/agents/design-critic.md`:

```markdown
Read `.claude/skills/evaluation/references/scoring-examples.md` for calibration before scoring.
```

With:

```markdown
Read `.claude/skills/evaluation/references/scoring-examples.md` for calibration before scoring.

Read `calibration-profile.json` from the project root for scoring configuration. If the file does not exist, use the defaults documented below. The calibration profile overrides:
- Scoring weights per criterion
- Pass threshold
- Per-criterion minimum score
- Max iterations and plateau detection settings
```

- [ ] **Step 2: Add per-criterion minimum to the Threshold section**

Replace the Threshold section (lines 75-79) with:

```markdown
## Threshold

Read `calibration-profile.json` for `scoring.threshold` (default: **7**) and `scoring.per_criterion_minimum` (default: **5**).

Two conditions must BOTH be met for Layer 3 to PASS:
1. The weighted average meets or exceeds `threshold`
2. ALL four individual scores meet or exceed `per_criterion_minimum`

A high weighted average cannot mask a critically weak criterion. Example: DQ=9, O=9, C=9, F=4 → weighted average = 7.8 (above threshold) but Functionality=4 < minimum=5 → **FAIL**.
```

- [ ] **Step 3: Replace Iteration Limit section with plateau detection**

Replace the Iteration Limit section (lines 81-83) with:

```markdown
## Iteration Control

Read `calibration-profile.json` for iteration settings:
- `iteration.max_iterations` — Maximum iterations per story (default: **10** in Full mode)
- `iteration.plateau_window` — Number of recent scores to check for stagnation (default: **3**)
- `iteration.plateau_delta` — If max - min of recent scores < this value, scores have plateaued (default: **0.3**)
- `iteration.pivot_after_plateau` — If true, force a design pivot on plateau (default: **true**)

### Plateau Detection

After each iteration, check the last `plateau_window` weighted scores:
1. Compute `delta = max(recent_scores) - min(recent_scores)`
2. If `delta < plateau_delta`, scores have plateaued
3. If `pivot_after_plateau` is true: instruct the generator to make a **fundamental change** — different color palette, different layout structure, different typography pairing. Not incremental tweaks.
4. If `pivot_after_plateau` is false: log a warning and continue with incremental critique

If `max_iterations` is reached and score is still below threshold: log to `failures.md`, extract a learned rule describing the persistent issue, escalate to user. Do NOT revert — the ratchet gate (tests, lint, coverage) has already passed.
```

- [ ] **Step 4: Update Scoring Weights section to reference calibration profile**

Replace the first line of the Scoring Weights section (line 61-62) with:

```markdown
### Scoring Weights

Read weights from `calibration-profile.json` field `scoring.weights`. Defaults below if no profile exists:
```

Keep the existing weights table and formula unchanged (they serve as the defaults).

- [ ] **Step 5: Verify the file**

Run: `cat -n .claude/agents/design-critic.md | head -5 && echo "---" && wc -l .claude/agents/design-critic.md`
Expected: File starts with frontmatter, total ~185-195 lines.

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/design-critic.md
git commit -m "feat(design-critic): add calibration profile support, plateau detection, per-criterion minimum"
```

---

### Task 4: Add Dependency Handshake to Generator

**Files:**
- Modify: `.claude/agents/generator.md:52-88` (Workflow section)

- [ ] **Step 1: Insert new Step 2.5 — Dependency Handshake**

After the existing Step 2 (Read Stories and Component Map, lines 59-63) and before Step 3 (Spawn Agent Team, lines 65-69), insert:

```markdown
### Step 2.5: Dependency Handshake (Before Spawning Teammates)

Before spawning any teammates, analyze the component map for the current group:

1. **Identify shared files** — files that appear in 2+ stories within this group. These need an integrator.
2. **Identify interface boundaries** — where one story's output is consumed by another story (look for `Produces:` and `Consumes:` annotations in the component map).
3. **Build a micro-DAG** — group teammates into execution phases:
   - **Phase 1:** Teammates with no upstream dependencies (no `Consumes:` from another story in this group)
   - **Phase 2:** Teammates that consume Phase 1 outputs. They start only after Phase 1 teammates commit their typed interface contracts.
   - **Phase 3:** Integration wiring (if shared files need coordinated edits)
4. **Designate integrators** — for each shared file, assign one teammate as the owner. Other teammates declare what they need added (types, routes, exports) via task messaging.

If the component map has no `Produces:`/`Consumes:` annotations and no shared files, skip the handshake and spawn all teammates in parallel (current behavior).

Log the micro-DAG to `iteration-log.md`:
```
Group C micro-DAG:
  Phase 1: teammate-upload (produces: UploadResult)
  Phase 2: teammate-process (consumes: UploadResult, produces: ProcessedDocument)
  Phase 3: teammate-upload integrates shared types.py
```
```

- [ ] **Step 2: Update Step 3 (Spawn Agent Team) for phased execution**

Replace the existing Step 3 content (lines 65-69) with:

```markdown
### Step 3: Spawn Agent Team

Execute teammates in phases from the micro-DAG:

**Phase 1 teammates** — spawn in parallel. Each teammate must:
- Implement their code with TDD
- Define typed interface contracts for any `Produces:` outputs (Pydantic model or TypeScript interface)
- Commit their interface contracts before signaling completion

**Phase 2 teammates** — spawn in parallel after ALL Phase 1 teammates complete. Each receives:
- The typed interface contracts from Phase 1 (read from committed files)
- Their story acceptance criteria and file ownership

**Phase 3 (integration)** — if shared files exist, the designated integrator:
- Collects all declared additions from teammates via task messaging
- Writes all additions to the shared file in a single commit
- No other teammate writes to shared files

**Teammate prompt must include:**
- Story acceptance criteria
- File ownership (which files this teammate may edit)
- Learned rules (from `.claude/state/learned-rules.md`)
- Quality principles (from `.claude/skills/code-gen/SKILL.md`)
- Interface contracts from upstream teammates (Phase 2+ only)
- If the story involves an external API: include `.claude/skills/code-gen/references/api-integration-patterns.md`

Max 5 concurrent teammates per phase. If a phase has >5 stories, batch in groups of 5.
```

- [ ] **Step 3: Add interface contract rule to Quality Principles**

After the existing Quality Principles section (line 90-97), add:

```markdown
- When your story produces output consumed by another story, define the typed interface contract (Pydantic model / TypeScript interface) FIRST, before writing implementation logic. Commit the contract so downstream teammates can code against it.
```

- [ ] **Step 4: Verify the file**

Run: `wc -l .claude/agents/generator.md`
Expected: ~165-175 lines.

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/generator.md
git commit -m "feat(generator): add dependency handshake, micro-DAG phased execution, integrator pattern"
```

---

### Task 5: Update Auto Section 4 for Phase-Aware Execution

**Files:**
- Modify: `.claude/skills/auto/SKILL.md:93-139` (Section 4)

- [ ] **Step 1: Replace Section 4 header and intro**

Replace the Section 4 content (lines 93-139) with phase-aware execution. Keep the section number and heading style consistent with the rest of the file. The new section should be:

```markdown
## SECTION 4: Agent Team Execution (Step 4)

### Dependency Handshake

Before spawning teammates, the generator analyzes the component map:
1. Identifies shared files (files in 2+ stories)
2. Identifies interface boundaries (`Produces:` / `Consumes:` in component map)
3. Builds a micro-DAG grouping teammates into execution phases
4. Designates integrators for shared files

Log the micro-DAG to `iteration-log.md`.

If no cross-dependencies exist, all teammates spawn in parallel (legacy behavior).

### Phased Execution

| Phase | Who | Starts When | Must Do |
|-------|-----|------------|---------|
| 1 | Teammates with no upstream deps | Immediately | Implement + commit typed interface contracts |
| 2 | Teammates consuming Phase 1 outputs | All Phase 1 teammates complete | Code against committed interface contracts |
| 3 | Integrators for shared files | All Phase 2 teammates complete | Collect declared additions, write to shared files |

Max 5 concurrent teammates per phase. Batch in groups of 5 if more.

### Teammate Spawn Prompt

Every teammate receives:
- Story acceptance criteria (from `specs/stories/story-NNN.md`)
- File ownership (from `specs/design/component-map.md`)
- Learned rules (from `.claude/state/learned-rules.md` — inject verbatim)
- Quality principles (from `.claude/skills/code-gen/SKILL.md`)
- Interface contracts from upstream teammates (Phase 2+ only)
- If story involves external API: `.claude/skills/code-gen/references/api-integration-patterns.md`

### Solo Mode

In Solo mode, the generator works alone sequentially. No team spawning, no phases. Read stories in dependency order and implement one at a time.

### Model Tiering

| Role | Model | Rationale |
|------|-------|-----------|
| `/auto` orchestrator | Opus | Judgment, architectural decisions |
| Evaluator | Opus | Skeptical verification |
| Design critic | Opus | Subjective visual judgment |
| Generator lead | Sonnet | Coordination, lower cost |
| Generator teammates | Sonnet | Mechanical implementation |
| Security reviewer | Sonnet | Pattern matching |

Configure via `project-manifest.json` field `execution.model_tier`.
```

- [ ] **Step 2: Verify section numbering is consistent**

Run: `grep -n "^## SECTION" .claude/skills/auto/SKILL.md`
Expected: Sections 1-13 in order, Section 4 now says "Agent Team Execution (Step 4)".

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/auto/SKILL.md
git commit -m "feat(auto): section 4 phase-aware agent team execution with micro-DAG"
```

---

### Task 6: Update Auto Section 6 for Structured Self-Healing

**Files:**
- Modify: `.claude/skills/auto/SKILL.md:232-283` (Section 6)

- [ ] **Step 1: Add structured failure JSON to FAIL handling**

In the Section 6 FAIL handling, after the existing failure classification table, add the structured failure passthrough. Insert after the classification table but before the 3rd-failure hard stop:

```markdown
### Structured Failure Passthrough

When spawning the generator for a self-heal attempt, pass the evaluator's structured failure JSON (from `specs/reviews/eval-failures-NNN.json`):

```json
{
  "failure": {
    "layer": "api",
    "gate": "evaluator",
    "check": "POST /api/users -> 201",
    "actual": { "status": 500, "body": "..." },
    "stack_trace": "...",
    "error_type": "key_error",
    "files_likely_involved": ["backend/src/service/user_service.py:45"],
    "prior_attempts": [
      {
        "attempt": 1,
        "fix_applied": "Added null check for email field",
        "result": "Same error — email field is present but payload is FormData not JSON"
      }
    ]
  }
}
```

**Accumulate prior_attempts:** On attempt 2, include attempt 1's fix and result. On attempt 3, include both. This prevents the generator from re-trying the same fix.

**Error type to fix strategy mapping:**

| error_type | Strategy |
|-----------|----------|
| `lint_format` | Run `ruff check --fix && ruff format` or `eslint --fix` |
| `type_error` | Fix annotation at file:line from stack trace |
| `import_error` | Check module path, fix import statement |
| `key_error` | Check data shape at source — log incoming data, fix accessor |
| `timeout` | Check if service is started, increase timeout, add retry |
| `connection_refused` | Verify service URL in config, check port mapping |
| `validation_error` | Compare request/response against schema, fix model |
| `assertion_error` | Read test assertion, compare expected vs actual, fix logic |
| `api_transient` | Retry evaluator check (code may be correct, API was flaky) |
| `api_permanent` | Fix wrapper error handling or request format |

For `api_transient`: retry the evaluator check once before counting as a self-heal attempt. If it passes on retry, continue without consuming an attempt.
```

- [ ] **Step 2: Verify section structure**

Run: `grep -n "prior_attempts\|Structured Failure\|error_type" .claude/skills/auto/SKILL.md`
Expected: New content appears within Section 6.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/auto/SKILL.md
git commit -m "feat(auto): section 6 structured failure JSON with prior_attempts accumulation"
```

---

### Task 7: Update Auto Section 7 — App Lifecycle Management

**Files:**
- Modify: `.claude/skills/auto/SKILL.md:286-334` (Section 7)

- [ ] **Step 1: Replace Section 7 with mode-aware app lifecycle**

Replace Section 7 (lines 286-334) with:

```markdown
## SECTION 7: App Lifecycle Management

Read `verification.mode` from `project-manifest.json`. Default: `docker`.

### Mode: docker (default)

**Startup:**
1. Run `bash init.sh` before first evaluator check
2. Run health-check retry loop (see evaluator agent for protocol)
3. If health check fails: FAIL the current group, log to failures.md

**Between Groups:**
```bash
docker compose up -d --build
```
Wait for health check before handing off to evaluator.

**Teardown:**
```bash
docker compose down -v
```

**Error Context:** `docker compose logs --tail=50 {service_name}`

### Mode: local

**Startup:**
1. Read `verification.local.start_commands` from manifest
2. Start each command as a background process, capture stdout/stderr to `.claude/state/process-{name}.log`
3. Run health-check retry loop against configured URLs

**Between Groups:** Kill and restart processes with `--build` equivalent (e.g., re-run start commands).

**Teardown:** Kill all background processes started by the orchestrator.

**Error Context:** Read from `.claude/state/process-{name}.log`

### Mode: stub

**Startup:**
1. Read `verification.stub.schema_source` from manifest
2. Generator creates a lightweight mock server (FastAPI or Express) that serves schema-valid example responses for every endpoint in the schema
3. Start the mock server on a free port
4. Run health-check retry loop

**Between Groups:** Regenerate mock server if schema has been amended (check `specs/design/amendments/`).

**Teardown:** Kill mock server process.

**Error Context:** Stub mismatch reports — when a request doesn't match any endpoint in the schema, log the requested path and method.

**Stub mode limitations:** Layer 1 checks validate request/response shapes but cannot verify business logic. Layer 2 (Playwright) skipped unless a separate frontend URL is configured.

### Worktree Isolation (All Modes)

When using `--worktree` flag, each worktree gets its own app instance:
- Docker mode: different port mappings (configured via `project-manifest.json`)
- Local mode: different port arguments in start commands
- Stub mode: different mock server port (auto-selected)
```

- [ ] **Step 2: Verify section numbering**

Run: `grep -n "^## SECTION" .claude/skills/auto/SKILL.md`
Expected: Section 7 now says "App Lifecycle Management".

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/auto/SKILL.md
git commit -m "feat(auto): section 7 app lifecycle management with docker/local/stub modes"
```

---

### Task 8: Update Auto Section 9 for Configurable Calibration

**Files:**
- Modify: `.claude/skills/auto/SKILL.md:352-390` (Section 9)

- [ ] **Step 1: Update Section 9 to read calibration profile**

Replace the Section 9 content (lines 352-390) with:

```markdown
## SECTION 9: GAN Design Loop (Frontend Groups Only, Full Mode)

Read `calibration-profile.json` for all scoring and iteration parameters. Fall back to defaults if file does not exist.

### Configuration

| Parameter | Source | Default |
|-----------|--------|---------|
| Scoring weights | `calibration-profile.json` → `scoring.weights` | DQ=1.5, O=1.5, C=0.75, F=0.75 |
| Pass threshold | `calibration-profile.json` → `scoring.threshold` | 7 |
| Per-criterion minimum | `calibration-profile.json` → `scoring.per_criterion_minimum` | 5 |
| Max iterations | `calibration-profile.json` → `iteration.max_iterations` | 10 |
| Plateau window | `calibration-profile.json` → `iteration.plateau_window` | 3 |
| Plateau delta | `calibration-profile.json` → `iteration.plateau_delta` | 0.3 |
| Pivot on plateau | `calibration-profile.json` → `iteration.pivot_after_plateau` | true |

### Loop

For each frontend page in the current group:

1. **Screenshot** — Take screenshots of the page at 1280px and 375px widths using Playwright
2. **Score** — Spawn design-critic agent with screenshots + calibration profile
3. **Check threshold** — weighted average >= threshold AND all criteria >= per_criterion_minimum
4. **If PASS** — Record score to `specs/reviews/eval-scores.json`, continue to next page
5. **If FAIL** — Send critique to generator, generator iterates on UI code

### Plateau Detection

After each iteration, check the last `plateau_window` weighted scores:
- If `max(recent) - min(recent) < plateau_delta`: scores have plateaued
- If `pivot_after_plateau` is true: instruct generator to make a fundamental change (different palette, layout, or typography) — not incremental tweaks
- If false: log warning, continue with incremental critique

### Termination

- Score meets threshold → PASS, move to next page
- `max_iterations` reached → log to `failures.md`, extract learned rule, escalate to user. Do NOT revert (ratchet gate already passed for functional checks).
- Lean/Solo/Turbo modes: skip this section entirely
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/auto/SKILL.md
git commit -m "feat(auto): section 9 configurable GAN design loop via calibration-profile.json"
```

---

### Task 9: Add LLM Integration Rules to Code-Gen Skill

**Files:**
- Modify: `.claude/skills/code-gen/SKILL.md` — insert after the Testing Rules section (~line 100)

- [ ] **Step 1: Add LLM Integration section**

After the Testing Rules section (ending ~line 100) and before the Parallel Execution section (line 103), insert:

```markdown
## LLM Integration — Structured Output Mandatory

When generated code calls any LLM (Claude, GPT, or other), follow these rules:

### 1. Always Use Structured Output

Use `tool_use` / `function_calling` / `response_format: { type: "json_schema", json_schema: ... }` for every LLM call. Never parse free-text responses with regex or string splitting.

### 2. Define a Response Schema

Every LLM call must have a typed model for the expected response:

```python
from pydantic import BaseModel
from typing import Literal

class ClassificationResult(BaseModel):
    category: str
    confidence: Literal["high", "medium", "low"]
    reasoning: str
```

```typescript
interface ClassificationResult {
  category: string;
  confidence: "high" | "medium" | "low";
  reasoning: string;
}
```

### 3. Validate Before Using

Parse the LLM response through the schema. If validation fails:
1. Retry once with an explicit correction prompt: "Your response did not match the required schema. Required: {schema}. Please respond again."
2. If second attempt fails, raise a typed error — do not fall back to a default value.

### 4. No Silent Fallbacks

Never write:
```python
# WRONG — hides bugs that compound
try:
    result = await call_llm(prompt)
    parsed = ResponseModel.model_validate_json(result)
except Exception:
    parsed = ResponseModel(category="unknown", confidence="low", reasoning="")
```

Instead:
```python
# CORRECT — caller decides how to handle failure
class LLMResponseError(Exception):
    def __init__(self, raw_response: str, validation_error: str):
        self.raw_response = raw_response
        self.validation_error = validation_error
        super().__init__(f"LLM response validation failed: {validation_error}")

try:
    result = await call_llm(prompt)
    parsed = ResponseModel.model_validate_json(result)
except ValidationError as e:
    raise LLMResponseError(raw_response=result, validation_error=str(e))
```

### 5. Log Raw Responses

Always log the raw LLM response at DEBUG level before parsing:

```python
logger.debug(
    "LLM response received",
    extra={
        "provider": self._provider_name,
        "model": self._model,
        "prompt_tokens": response.usage.input_tokens,
        "completion_tokens": response.usage.output_tokens,
        "raw_content": response.content[:1000],
        "latency_ms": round(elapsed_ms, 2),
    },
)
```
```

- [ ] **Step 2: Add LLM gotchas to the Gotchas section**

At the end of the Gotchas section (after line 123), append:

```markdown
- **Free-text LLM parsing** — Never use regex to parse LLM output. Use structured output (tool_use / JSON mode).
- **Silent fallback on LLM error** — `except Exception: return default` hides compounding bugs. Raise typed errors.
- **Missing raw response logging** — Always log raw LLM response at DEBUG before parsing. This is the debugging ground truth.
```

- [ ] **Step 3: Verify the file**

Run: `wc -l .claude/skills/code-gen/SKILL.md`
Expected: ~210-220 lines.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/code-gen/SKILL.md
git commit -m "feat(code-gen): add LLM integration rules — structured output, no silent fallbacks"
```

---

### Task 10: Add External API Integration Section to Code-Gen Skill

**Files:**
- Modify: `.claude/skills/code-gen/SKILL.md` — insert after the new LLM Integration section

- [ ] **Step 1: Add External API Integration section**

Insert after the LLM Integration section:

```markdown
## External API Integration

When generated code calls any external API (third-party services, partner APIs, cloud services), follow these rules. See `.claude/skills/code-gen/references/api-integration-patterns.md` for full templates.

### Service Wrapper Pattern (Mandatory)

Every external API gets a dedicated wrapper class. This is the ONLY file that imports the SDK or makes HTTP calls to that service.

```
Business Logic (process_service.py)
    ↓ calls typed methods
API Wrapper (external_client.py)    ← only file that imports SDK / makes HTTP calls
    ↓ calls
External API
```

Rules:
- One wrapper class per external API
- Wrapper exposes project-internal typed models, not SDK types
- Business logic never sees SDK response objects — only your domain types
- The wrapper is the mock boundary in tests

### Error Taxonomy (Mandatory)

Every wrapper classifies errors into typed categories:

```python
class ApiTransientError(Exception):
    """Retryable: 429, 502, 503, timeout, connection reset."""
    pass

class ApiPermanentError(Exception):
    """Not retryable: 400, 401, 403, 404, schema mismatch."""
    pass

class ApiRateLimitError(ApiTransientError):
    """Rate limited with backoff hint."""
    def __init__(self, message: str, retry_after: float | None = None):
        super().__init__(message)
        self.retry_after = retry_after
```

- Business logic catches `ApiTransientError` to retry/degrade, `ApiPermanentError` to fail fast
- No bare `except Exception` in any API-calling code
- All exceptions carry HTTP status code and response body for debugging

### Retry and Rate Limiting

- Retry config lives in `config.yml` under `external_apis.{service_name}.retry`, not hardcoded
- Wrapper applies exponential backoff internally — business logic is unaware of retries
- Respect `Retry-After` headers when present
- Log every retry attempt at WARNING level

### Async Bridging

When an SDK is synchronous but the backend is async:
- Use `asyncio.to_thread()` only inside the wrapper class
- Never bridge in business logic
- Prefer async SDKs or HTTP clients when available

### Secrets

- API keys in `.env` only, loaded via config layer
- Wrapper reads from injected config, never from `os.environ` directly
- `.env.example` committed with placeholder values
```

- [ ] **Step 2: Add API gotchas to the Gotchas section**

Append to the Gotchas section:

```markdown
- **Direct SDK imports outside wrapper** — All SDK imports must be inside the wrapper class file. Business logic imports your wrapper, not the SDK.
- **Bare except on API calls** — Catch `ApiTransientError` and `ApiPermanentError` specifically. Never `except Exception`.
- **Hardcoded retry config** — Retry attempts, backoff, and timeout belong in `config.yml`, not in code.
- **Missing structured logging in API wrapper** — Every request/response/error must be logged with structured fields (service, operation, attempt, latency_ms).
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/code-gen/SKILL.md
git commit -m "feat(code-gen): add external API integration rules — wrapper pattern, error taxonomy, retry"
```

---

### Task 11: Add Production Standards Section to Code-Gen Skill

**Files:**
- Modify: `.claude/skills/code-gen/SKILL.md` — insert after External API Integration section

- [ ] **Step 1: Add Production Standards section**

Insert after the External API Integration section:

```markdown
## Production Standards

These standards apply to ALL generated code, not just API wrappers or LLM calls.

### Structured Logging

All generated services must use structured logging with `extra` dicts:

```python
import logging

logger = logging.getLogger(__name__)

# CORRECT — structured fields for JSON log formatters
logger.info("Document processed", extra={
    "document_id": doc.id,
    "processing_time_ms": round(elapsed_ms, 2),
    "output_size_bytes": len(result),
})

# WRONG — data interpolated into message string
logger.info(f"Document {doc.id} processed in {elapsed_ms}ms")
```

```typescript
// CORRECT — structured logger
logger.info("Document processed", {
  documentId: doc.id,
  processingTimeMs: Math.round(elapsedMs),
  outputSizeBytes: result.length,
});

// WRONG — template literal message
logger.info(`Document ${doc.id} processed in ${elapsedMs}ms`);
```

Rules:
- Use `logging.getLogger(__name__)` (Python) or scoped logger (TypeScript) at module level
- INFO for business events (request received, document processed, job completed)
- WARNING for recoverable issues (retry triggered, fallback used, slow response)
- ERROR for failures requiring attention (unhandled exception, data corruption, external service down)
- DEBUG for troubleshooting data (raw payloads, intermediate state, timing breakdowns)
- Never log secrets, tokens, passwords, or PII
- Log at service boundaries: incoming requests, outgoing calls, business decisions

### Exception Handling

```python
# CORRECT — typed exception with context
class DocumentProcessingError(Exception):
    def __init__(self, document_id: str, stage: str, cause: Exception):
        self.document_id = document_id
        self.stage = stage
        self.cause = cause
        super().__init__(f"Failed at {stage} for document {document_id}: {cause}")

# WRONG — bare except swallowing the error
try:
    result = process(doc)
except Exception:
    result = default_value
```

Rules:
- Define typed exception classes per domain (not per function)
- Every exception carries enough context to debug without the stack trace
- Never catch `Exception` or `BaseException` unless re-raising or logging at a top-level boundary
- No silent fallbacks — if an operation fails, the caller must know
- API route handlers catch domain exceptions and map to HTTP error responses

### Structured Error Responses

All API error responses follow a consistent envelope:

```json
{
  "error": {
    "code": "DOCUMENT_NOT_FOUND",
    "message": "Document with ID abc123 does not exist",
    "details": {}
  }
}
```

Rules:
- `code` is a machine-readable UPPER_SNAKE_CASE string enum
- `message` is human-readable
- `details` is optional structured context
- HTTP status mapping: 400 validation, 404 not found, 409 conflict, 422 processing error, 500 internal

### Request/Response Validation

- All API inputs validated via Pydantic models (Python) or Zod schemas (TypeScript)
- Validation errors return 400 with field-level messages
- All API outputs serialized through response models — never return raw dicts or ORM objects

### Configuration

- All configurable values in `config.yml` or environment variables
- No magic numbers or hardcoded strings in business logic
- Config loaded once at startup, injected into services via constructor
- Defaults provided for all non-secret config values
```

- [ ] **Step 2: Add production standards gotchas**

Append to the Gotchas section:

```markdown
- **f-string log messages** — Use `extra` dict for structured fields, not string interpolation. Structured logs are searchable; f-strings are not.
- **Missing logging at service boundaries** — Every incoming request and outgoing call must be logged with timing and status.
- **Raw dict API responses** — Always serialize through a response model. Raw dicts bypass validation and leak internal structure.
- **Magic numbers** — All thresholds, limits, timeouts, and configuration belong in `config.yml`.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/code-gen/SKILL.md
git commit -m "feat(code-gen): add production standards — structured logging, exception handling, error responses"
```

---

### Task 12: Create API Integration Patterns Reference Doc

**Files:**
- Create: `.claude/skills/code-gen/references/api-integration-patterns.md`

- [ ] **Step 1: Verify directory exists**

Run: `ls .claude/skills/code-gen/references/ 2>/dev/null || echo "need to create"`

Create the directory if needed: `mkdir -p .claude/skills/code-gen/references/`

- [ ] **Step 2: Create the reference document**

Write `.claude/skills/code-gen/references/api-integration-patterns.md`:

```markdown
# External API Integration Patterns

Reference templates for generator teammates. When a story involves an external API, read this file before implementation.

---

## 1. Service Wrapper Template (Python)

```python
import asyncio
import json
import logging
import time
from pathlib import Path
from typing import Any

from config import ApiConfig
from types import OperationRequest, OperationResponse

logger = logging.getLogger(__name__)


class ApiTransientError(Exception):
    """Retryable: 429, 502, 503, timeout, connection reset."""
    pass


class ApiPermanentError(Exception):
    """Not retryable: 400, 401, 403, 404, schema mismatch."""
    pass


class ApiRateLimitError(ApiTransientError):
    """Rate limited with backoff hint."""
    def __init__(self, message: str, retry_after: float | None = None):
        super().__init__(message)
        self.retry_after = retry_after


class ExternalServiceClient:
    """Wrapper for ExternalService API.

    This is the ONLY file that imports the ExternalService SDK.
    Business logic uses this wrapper's typed interface.
    """

    def __init__(self, config: ApiConfig, replay: bool = False):
        self._config = config
        self._service_name = "external_service"
        self._replay = replay
        self._fixtures_dir = Path(f"tests/fixtures/{self._service_name}")
        self._client = self._build_client(config)

    def _build_client(self, config: ApiConfig) -> Any:
        """Initialize the SDK client. Override for testing."""
        # Import SDK here — nowhere else in the codebase
        # from external_sdk import Client
        # return Client(api_key=config.api_key, base_url=config.base_url)
        raise NotImplementedError("Replace with actual SDK initialization")

    async def execute_operation(self, request: OperationRequest) -> OperationResponse:
        """Execute operation with retry, logging, and error classification."""
        start = time.monotonic()
        attempt = 0
        last_error: Exception | None = None

        while attempt < self._config.retry.max_attempts:
            attempt += 1
            try:
                logger.info(
                    "API request started",
                    extra={
                        "service": self._service_name,
                        "operation": "execute_operation",
                        "attempt": attempt,
                    },
                )

                raw = await self._call(request)

                elapsed_ms = (time.monotonic() - start) * 1000
                logger.info(
                    "API request completed",
                    extra={
                        "service": self._service_name,
                        "operation": "execute_operation",
                        "attempt": attempt,
                        "latency_ms": round(elapsed_ms, 2),
                        "status": "success",
                    },
                )

                return OperationResponse.from_raw(raw)

            except ApiRateLimitError as e:
                last_error = e
                backoff = e.retry_after or self._compute_backoff(attempt)
                logger.warning(
                    "API rate limited",
                    extra={
                        "service": self._service_name,
                        "operation": "execute_operation",
                        "attempt": attempt,
                        "retry_after": backoff,
                    },
                )
                if attempt < self._config.retry.max_attempts:
                    await asyncio.sleep(backoff)

            except ApiTransientError as e:
                last_error = e
                elapsed_ms = (time.monotonic() - start) * 1000
                logger.warning(
                    "API transient error, retrying",
                    extra={
                        "service": self._service_name,
                        "operation": "execute_operation",
                        "attempt": attempt,
                        "error": str(e),
                        "latency_ms": round(elapsed_ms, 2),
                    },
                )
                if attempt < self._config.retry.max_attempts:
                    await asyncio.sleep(self._compute_backoff(attempt))

            except ApiPermanentError:
                elapsed_ms = (time.monotonic() - start) * 1000
                logger.error(
                    "API permanent error",
                    extra={
                        "service": self._service_name,
                        "operation": "execute_operation",
                        "attempt": attempt,
                        "latency_ms": round(elapsed_ms, 2),
                    },
                )
                raise

        raise last_error or ApiTransientError("Max retries exceeded")

    async def _call(self, request: OperationRequest) -> dict:
        """Make the actual API call. Handles replay mode and sync bridging."""
        if self._replay:
            fixture_path = self._fixtures_dir / f"{request.operation_name}.json"
            logger.debug("Replaying fixture", extra={"path": str(fixture_path)})
            return json.loads(fixture_path.read_text())

        # Sync SDK bridge — use asyncio.to_thread for sync-only SDKs
        return await asyncio.to_thread(
            self._client.operation,
            **request.to_sdk_params(),
        )

    def _compute_backoff(self, attempt: int) -> float:
        return self._config.retry.backoff_base * (
            self._config.retry.backoff_multiplier ** (attempt - 1)
        )
```

## 2. Service Wrapper Template (TypeScript)

```typescript
import { Logger } from "../config/logger";

interface ApiConfig {
  baseUrl: string;
  apiKey: string;
  timeoutMs: number;
  retry: {
    maxAttempts: number;
    backoffBase: number;
    backoffMultiplier: number;
  };
}

export class ApiTransientError extends Error {
  constructor(message: string, public statusCode?: number) {
    super(message);
    this.name = "ApiTransientError";
  }
}

export class ApiPermanentError extends Error {
  constructor(message: string, public statusCode?: number, public responseBody?: string) {
    super(message);
    this.name = "ApiPermanentError";
  }
}

export class ApiRateLimitError extends ApiTransientError {
  constructor(message: string, public retryAfter?: number) {
    super(message, 429);
    this.name = "ApiRateLimitError";
  }
}

export class ExternalServiceClient {
  private readonly serviceName = "external_service";
  private readonly logger: Logger;

  constructor(
    private readonly config: ApiConfig,
    private readonly replay: boolean = false,
  ) {
    this.logger = new Logger(this.serviceName);
  }

  async executeOperation(request: OperationRequest): Promise<OperationResponse> {
    const start = performance.now();
    let attempt = 0;
    let lastError: Error | null = null;

    while (attempt < this.config.retry.maxAttempts) {
      attempt++;
      try {
        this.logger.info("API request started", {
          operation: "executeOperation",
          attempt,
        });

        const raw = await this.call(request);
        const elapsedMs = performance.now() - start;

        this.logger.info("API request completed", {
          operation: "executeOperation",
          attempt,
          latencyMs: Math.round(elapsedMs),
          status: "success",
        });

        return OperationResponse.fromRaw(raw);
      } catch (e) {
        if (e instanceof ApiPermanentError) {
          const elapsedMs = performance.now() - start;
          this.logger.error("API permanent error", {
            operation: "executeOperation",
            attempt,
            latencyMs: Math.round(elapsedMs),
          });
          throw e;
        }

        if (e instanceof ApiTransientError) {
          lastError = e;
          const backoff =
            e instanceof ApiRateLimitError && e.retryAfter
              ? e.retryAfter * 1000
              : this.computeBackoff(attempt);

          this.logger.warn("API transient error, retrying", {
            operation: "executeOperation",
            attempt,
            error: e.message,
            backoffMs: backoff,
          });

          if (attempt < this.config.retry.maxAttempts) {
            await new Promise((r) => setTimeout(r, backoff));
          }
        }
      }
    }

    throw lastError ?? new ApiTransientError("Max retries exceeded");
  }

  private async call(request: OperationRequest): Promise<Record<string, unknown>> {
    if (this.replay) {
      const fs = await import("fs/promises");
      const fixture = await fs.readFile(
        `tests/fixtures/${this.serviceName}/${request.operationName}.json`,
        "utf-8",
      );
      return JSON.parse(fixture);
    }

    const response = await fetch(`${this.config.baseUrl}${request.path}`, {
      method: request.method,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.config.apiKey}`,
      },
      body: JSON.stringify(request.body),
      signal: AbortSignal.timeout(this.config.timeoutMs),
    });

    if (response.status === 429) {
      const retryAfter = Number(response.headers.get("Retry-After")) || undefined;
      throw new ApiRateLimitError("Rate limited", retryAfter);
    }
    if (response.status >= 500) {
      throw new ApiTransientError(`Server error: ${response.status}`, response.status);
    }
    if (!response.ok) {
      const body = await response.text();
      throw new ApiPermanentError(`Client error: ${response.status}`, response.status, body);
    }

    return response.json();
  }

  private computeBackoff(attempt: number): number {
    return (
      this.config.retry.backoffBase *
      this.config.retry.backoffMultiplier ** (attempt - 1) *
      1000
    );
  }
}
```

## 3. Config Template

```yaml
# config.yml — external API configuration
external_apis:
  service_name:
    base_url: "${SERVICE_BASE_URL}"
    timeout_seconds: 30
    retry:
      max_attempts: 3
      backoff_base: 1.0
      backoff_multiplier: 2.0
      retryable_status_codes: [429, 502, 503]
    rate_limit:
      requests_per_minute: 60
      respect_retry_after: true
```

## 4. Test Fixture Pattern

### Recording Fixtures

```python
# scripts/record_fixtures.py
"""One-time script to record API responses for replay testing."""
import asyncio
import json
from pathlib import Path

from config import load_config

async def record(service_name: str, operation: str):
    config = load_config()
    client = build_real_client(config, service_name)
    response = await client.execute_operation(build_sample_request(operation))

    fixture_dir = Path(f"tests/fixtures/{service_name}")
    fixture_dir.mkdir(parents=True, exist_ok=True)
    (fixture_dir / f"{operation}.json").write_text(
        json.dumps(response.to_raw(), indent=2)
    )
    print(f"Recorded: {fixture_dir / f'{operation}.json'}")

if __name__ == "__main__":
    import sys
    asyncio.run(record(sys.argv[1], sys.argv[2]))
```

### Unit Test (Mock the Wrapper)

```python
# tests/unit/test_process_service.py
import pytest
from unittest.mock import AsyncMock
from service.process_service import ProcessService
from types import OperationResponse

@pytest.fixture
def mock_client():
    client = AsyncMock()
    client.execute_operation.return_value = OperationResponse(
        id="123",
        status="completed",
        result={"key": "value"},
    )
    return client

async def test_process_calls_external_api(mock_client):
    service = ProcessService(client=mock_client)
    result = await service.process(document_id="doc-1")

    mock_client.execute_operation.assert_called_once()
    assert result.document_id == "doc-1"
    assert result.status == "completed"
```

### Integration Test (Replay Mode)

```python
# tests/integration/test_external_client.py
import pytest
from clients.external_client import ExternalServiceClient
from config import load_test_config

@pytest.fixture
def replay_client():
    config = load_test_config()
    return ExternalServiceClient(config=config, replay=True)

async def test_operation_returns_expected_shape(replay_client):
    request = OperationRequest(operation_name="parse", params={"file": "test.pdf"})
    result = await replay_client.execute_operation(request)

    assert result.id is not None
    assert result.status in ("completed", "pending")
```
```

- [ ] **Step 3: Verify the file**

Run: `wc -l .claude/skills/code-gen/references/api-integration-patterns.md`
Expected: ~280-300 lines.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/code-gen/references/api-integration-patterns.md
git commit -m "feat(code-gen): add api-integration-patterns reference doc with Python/TypeScript templates"
```

---

### Task 13: Update Generator for API Integration Injection

**Files:**
- Modify: `.claude/agents/generator.md` — Step 3 teammate prompt section

- [ ] **Step 1: Add API integration detection to teammate spawning**

In the generator's Step 3 (Spawn Agent Team), the teammate prompt already includes learned rules and quality principles. Add after the quality principles line:

```markdown
- If the story's acceptance criteria mention an external API, third-party service, SDK, or webhook: include `.claude/skills/code-gen/references/api-integration-patterns.md` in the teammate prompt. The teammate must create the wrapper class FIRST, then build business logic against the wrapper's typed interface.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/generator.md
git commit -m "feat(generator): inject api-integration-patterns for stories involving external APIs"
```

---

### Task 14: Update Auto Self-Healing Error Categories

**Files:**
- Modify: `.claude/skills/auto/SKILL.md` — Section 6 failure classification table

- [ ] **Step 1: Add api_transient and api_permanent to the failure classification table**

In Section 6, find the existing failure classification table and append two new rows:

```markdown
| API transient error | `api_transient` | Retry evaluator check once (code may be correct). If retry fails, count as self-heal attempt and route to generator with structured failure JSON. |
| API permanent error | `api_permanent` | Route to generator with structured failure JSON. Generator fixes wrapper error handling or request format. |
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/auto/SKILL.md
git commit -m "feat(auto): add api_transient and api_permanent error categories to self-healing"
```

---

### Task 15: Update Scaffold to Generate Calibration Profile

**Files:**
- Modify: `.claude/commands/scaffold.md:10-35` (Steps 1-2), `:304-327` (Step 9)

- [ ] **Step 1: Add project type question to Step 1**

In Step 1 (Gather Project Info, ~line 10), add a question after the tech stack selection:

```markdown
4. **Project type** (for design calibration):
   - A) Consumer-facing app (high design bar)
   - B) Internal tool / dashboard (functional focus)
   - C) API-only / backend service (no UI scoring)
```

- [ ] **Step 2: Add verification mode question to Step 1**

Add another question:

```markdown
5. **Verification mode** (how will the evaluator reach the running app?):
   - A) Docker Compose (default — app runs in containers)
   - B) Local dev servers (app runs via npm/uvicorn/etc.)
   - C) Stub / mock server (no runnable backend — serverless or external-only)
```

- [ ] **Step 3: Add calibration-profile.json generation to Step 2**

After the `project-manifest.json` generation, add:

```markdown
### Generate calibration-profile.json

Based on the project type selection:

**If Consumer-facing app:**
```json
{
  "scoring": {
    "weights": { "design_quality": 1.5, "originality": 1.5, "craft": 1.5, "functionality": 1.0 },
    "threshold": 8,
    "per_criterion_minimum": 5
  },
  "iteration": {
    "max_iterations": 10,
    "plateau_window": 3,
    "plateau_delta": 0.3,
    "pivot_after_plateau": true
  }
}
```

**If Internal tool:**
```json
{
  "scoring": {
    "weights": { "design_quality": 0.75, "originality": 0.5, "craft": 0.5, "functionality": 1.5 },
    "threshold": 6,
    "per_criterion_minimum": 4
  },
  "iteration": {
    "max_iterations": 5,
    "plateau_window": 3,
    "plateau_delta": 0.3,
    "pivot_after_plateau": false
  }
}
```

**If API-only:**
Do not create `calibration-profile.json` (no UI scoring needed).
```

- [ ] **Step 4: Add verification block to project-manifest.json generation**

In the `project-manifest.json` template (Step 2), add the verification block based on the mode selection:

```markdown
### Add verification config to project-manifest.json

Based on verification mode selection, add to the manifest:

**If Docker:**
```json
"verification": {
  "mode": "docker",
  "health_check": { "url": "http://localhost:3000/health", "retries": 5, "backoff_seconds": 2 },
  "docker": { "compose_file": "docker-compose.yml", "services": ["backend", "frontend"] }
}
```

**If Local:**
```json
"verification": {
  "mode": "local",
  "health_check": { "url": "http://localhost:3000/health", "retries": 5, "backoff_seconds": 2 },
  "local": { "backend_url": "http://localhost:8000", "frontend_url": "http://localhost:3000", "start_commands": [] }
}
```

**If Stub:**
```json
"verification": {
  "mode": "stub",
  "health_check": { "url": "http://localhost:4000/health", "retries": 5, "backoff_seconds": 2 },
  "stub": { "schema_source": "specs/design/api-contracts.schema.json", "auto_generate_mock_server": true }
}
```
```

- [ ] **Step 5: Add calibration-profile.json to Step 9 state file initialization**

In Step 9 (Initialize State Files), add:

```markdown
- `calibration-profile.json` (if project type is not API-only) — created in Step 2
```

- [ ] **Step 6: Verify scaffold.md is valid**

Run: `wc -l .claude/commands/scaffold.md`
Expected: ~400-420 lines.

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/scaffold.md
git commit -m "feat(scaffold): add project type, verification mode questions, calibration-profile.json generation"
```

---

## Execution Order

Tasks can be executed in this dependency order:

```
Task 1 (evaluator verification modes)     ─── independent
Task 2 (scoring examples)                 ─── independent
Task 3 (design-critic calibration)        ─── depends on Task 2
Task 4 (generator dependency handshake)   ─── independent
Task 5 (auto section 4 phase-aware)       ─── depends on Task 4
Task 6 (auto section 6 structured failures) ─── depends on Task 1
Task 7 (auto section 7 app lifecycle)     ─── depends on Task 1
Task 8 (auto section 9 calibration)       ─── depends on Task 3
Task 9 (code-gen LLM integration)         ─── independent
Task 10 (code-gen external API)           ─── independent
Task 11 (code-gen production standards)   ─── independent
Task 12 (api-integration-patterns ref)    ─── depends on Task 10
Task 13 (generator API injection)         ─── depends on Task 12
Task 14 (auto self-healing categories)    ─── depends on Task 6
Task 15 (scaffold calibration + modes)    ─── depends on Tasks 1, 3
```

**Parallel groups:**
- Group A (independent): Tasks 1, 2, 4, 9, 10, 11
- Group B (after Group A): Tasks 3, 5, 6, 7, 12
- Group C (after Group B): Tasks 8, 13, 14
- Group D (after all): Task 15
