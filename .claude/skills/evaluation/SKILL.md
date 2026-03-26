# Evaluation Skill

Reference skill for the evaluator agent. Read this before running any sprint evaluation.

---

## Sprint Contract Format

A sprint contract is a JSON document that defines what must be verified at the end of a sprint.
It contains:
- `group` — the feature group or sprint identifier.
- `stories` — the user story IDs delivered in this sprint.
- `contract` — the verification checklist, divided into four check types:
  - `api_checks` — HTTP endpoint verifications (status codes, response shapes, error paths).
  - `playwright_checks` — browser-level UI flows verified via Playwright.
  - `design_checks` — subjective visual/UX criteria evaluated against the scoring rubric.
  - `architecture_checks` — structural code quality checks (layering, typing, folder structure).

Full schema: see `references/contract-schema.json`.
Scoring rubric for design checks: see `references/scoring-rubric.md`.
Playwright patterns: see `references/playwright-patterns.md`.

---

## Three-Layer Verification Workflow

Run checks in this order. Stop at the first blocking failure.

### Layer 1 — API Checks
1. For each entry in `contract.api_checks`, make the HTTP request as specified.
2. Assert status code, response body shape, and any specified field values.
3. Cover both success paths and documented error paths.
4. A single failed assertion is a FAIL — do not skip or rationalize.

### Layer 2 — Playwright Checks
1. For each entry in `contract.playwright_checks`, execute the browser flow.
2. Use selector patterns from `references/playwright-patterns.md` exclusively.
3. Assert visibility, text content, counts, and form state as specified.
4. Do not use `waitForTimeout`. Use `expect(...).toBeVisible()` with retry.

### Layer 3 — Design + Architecture Checks
1. Apply the scoring rubric from `references/scoring-rubric.md` to each design criterion.
2. Score each criterion 1–10. Record the score and the specific evidence.
3. For architecture checks, verify layering, typing, folder structure, and env var documentation.
4. Any architecture check failure is a FAIL regardless of design scores.

---

## Evaluator Behavioral Rules

These rules are non-negotiable. Deviation invalidates the evaluation.

1. **Execute every check.** Do not skip a check because a related check passed.
2. **Never rationalize a failure.** If the check specifies `status: 200` and you get `201`, that is a FAIL.
3. **Evidence over opinion.** Every verdict must cite specific output: response body, screenshot path, line number.
4. **No partial credit on binary checks.** API and Playwright checks are pass/fail. There is no "mostly works".
5. **Design scores are evidence-based.** Cite what you observed, not what you assumed.
6. **Do not infer intent.** If the contract says check X and X is absent, the check fails.
7. **Run checks in order.** Layer 1 before Layer 2 before Layer 3.
8. **Document every check result,** even passing ones. The evaluation report is the source of truth.

---

## Verdict Format

Produce a structured report after all checks are complete.

```
SPRINT EVALUATION REPORT
Sprint: {group}
Date: {ISO date}
Evaluator: {agent id}

VERDICT: PASS | FAIL

--- API CHECKS ---
[check-id] PASS | FAIL
  Expected: {what the contract required}
  Actual:   {what was observed}

--- PLAYWRIGHT CHECKS ---
[check-id] PASS | FAIL
  Flow: {description}
  Evidence: {screenshot path or DOM assertion result}

--- DESIGN CHECKS ---
[criterion] Score: {1-10}
  Evidence: {specific observation}

--- ARCHITECTURE CHECKS ---
[check-id] PASS | FAIL
  Finding: {specific file path or pattern observed}

SUMMARY
Passed: {n}/{total}
Failed checks: {list of failed check IDs}
Blocking issues: {list of FAIL items that prevent shipping}
```

A sprint is shippable only if VERDICT is PASS. A single FAIL on any Layer 1 or Layer 2 check,
or any architecture check, produces a FAIL verdict regardless of other results.
