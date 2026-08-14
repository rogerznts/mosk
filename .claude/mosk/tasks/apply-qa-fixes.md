<!-- Inspired by BMAD and SpecKit -->

# apply-qa-fixes

Implement fixes based on QA results (gate and assessments) for a specific story. This task is for the Dev agent to systematically consume QA outputs and apply code/test changes while only updating allowed sections in the story file.

## Purpose

- Read QA outputs for a story (gate YAML + assessment markdowns)
- Create a prioritized, deterministic fix plan
- Apply code and test changes to close gaps and address issues
- Update only the allowed story sections for the Dev agent

## Inputs

```yaml
required:
  - story_id: '{epic}.{story}' # e.g., "2.2"
  - qa_root: from `.claude/mosk/core-config.yaml` key `qa.qaLocation` (e.g., `docs/qa`)
  - story_root: from `.claude/mosk/core-config.yaml` keys `specs.root` + current spec + `specs.storiesSubdir` (e.g., `docs/specs/005-feature-checkout-coupon/stories`)

optional:
  - story_title: '{title}' # derive from story H1 if missing
  - story_slug: '{slug}' # derive from title (lowercase, hyphenated) if missing
```

## QA Sources to Read

- **Gate (YAML) — resolve in this order, and stop at the first hit:**
  1. **`{FEATURE_DIR}/gate.yaml`** — the per-spec gate. This is where `qa-gate`
     writes by default, and where the pipeline reads. **Look here first.**
  2. `{qa_root}/gates/{epic}.{story}-*.yml` — the story-level gate (BMAD
     lineage). If multiple, use the most recent by modified time.

  > Checking only the story-level path is what used to make this task HALT in the
  > normal spec-level flow: the gate existed, in the place `qa-gate` documents,
  > and this task reported it missing.
- Assessments (Markdown):
  - Test Design: `{qa_root}/assessments/{epic}.{story}-design-tests-*.md`
  - Traceability: `{qa_root}/assessments/{epic}.{story}-trace-*.md`
  - Risk Profile: `{qa_root}/assessments/{epic}.{story}-risk-*.md`
  - NFR Assessment: `{qa_root}/assessments/{epic}.{story}-nfr-*.md`

## Prerequisites

- Repository builds and tests run locally using the project's stack
- Lint and test commands available (use the project-specific runner, e.g., `npm test`, `pytest`, `go test ./...`, `cargo test`, etc.)

## Process (Do not skip steps)

### 0) Load Core Config & Locate Story

- Read `.claude/mosk/core-config.yaml` and resolve `qa_root` and `story_root`
- Locate story file in `{story_root}/{epic}.{story}.*.md`
  - HALT if missing and ask for correct story id/path

### 0.5) Register the phase

Applying QA fixes puts the spec back in `implement`. Record that, so the
metadata says where the work actually is:

```bash
source .claude/mosk/scripts/common.sh
update_spec_phase "$FEATURE_DIR" implement
```

This does **not** auto-iterate — you were routed here by a human decision, and
you will hand back to `/mosk-qa qa-gate` when the fixes are in.

### 1) Collect QA Findings

- Parse the latest gate YAML:
  - `gate` (PASS|CONCERNS|FAIL|WAIVED)
  - `top_issues[]` with `id`, `severity`, `finding`, `suggested_action`
  - `nfr_validation.*.status` and notes
  - `trace` coverage summary/gaps
  - `test_design.coverage_gaps[]`
  - `risk_summary.recommendations.must_fix[]` (if present)
- Read any present assessment markdowns and extract explicit gaps/recommendations

### 2) Build Deterministic Fix Plan (Priority Order)

Apply in order, highest priority first:

1. High severity items in `top_issues` (security/perf/reliability/maintainability)
2. NFR statuses: all FAIL must be fixed → then CONCERNS
3. Test Design `coverage_gaps` (prioritize P0 scenarios if specified)
4. Trace uncovered requirements (AC-level)
5. Risk `must_fix` recommendations
6. Medium severity issues, then low

Guidance:

- Prefer tests closing coverage gaps before/with code changes
- Keep changes minimal and targeted; follow project architecture and coding standards

### 3) Apply Changes

- Implement code fixes per plan
- Add missing tests to close coverage gaps (unit first; integration where required by AC)
- Follow existing import/dependency patterns defined in the project
- Follow existing DI/architecture boundaries and patterns defined in the project

### 4) Validate

- Run the project's lint command (e.g., `npm run lint`, `ruff check .`, `golangci-lint run`) and fix issues
- Run the project's test command (e.g., `npm test`, `pytest`, `go test ./...`) until all tests pass
- Iterate until clean

### 5) Update Story (Allowed Sections ONLY)

CRITICAL: Dev agent is ONLY authorized to update these sections of the story file. Do not modify any other sections (e.g., QA Results, Story, Acceptance Criteria, Dev Notes, Testing):

- Tasks / Subtasks Checkboxes (mark any fix subtask you added as done)
- Dev Agent Record →
  - Agent Model Used (if changed)
  - Debug Log References (commands/results, e.g., lint/tests)
  - Completion Notes List (what changed, why, how)
  - File List (all added/modified/deleted files)
- Change Log (new dated entry describing applied fixes)
- Status (see Rule below)

Status Rule:

- If gate was PASS and all identified gaps are closed → set `Status: Ready for Done`
- Otherwise → set `Status: Ready for Review` and notify QA to re-run the review

### 6) Do NOT Edit Gate Files

- Dev does not modify gate YAML. If fixes address issues, request QA to re-run `review-story` to update the gate

## Blocking Conditions

- Missing `.claude/mosk/core-config.yaml`
- Story file not found for `story_id`
- No QA artifacts found — **neither** `{FEATURE_DIR}/gate.yaml` **nor**
  `{qa_root}/gates/{epic}.{story}-*.yml` nor any assessment
  - HALT and request QA to generate at least a gate file (or proceed only with clear developer-provided fix list)

## Completion Checklist

- Lint: 0 problems (use project-specific lint command)
- All tests pass (use project-specific test command)
- All high severity `top_issues` addressed
- NFR FAIL → resolved; CONCERNS minimized or documented
- Coverage gaps closed or explicitly documented with rationale
- Story updated (allowed sections only) including File List and Change Log
- Status set according to Status Rule

## Example: Story 2.2

Given gate `docs/qa/gates/2.2-*.yml` shows

- `coverage_gaps`: Back action behavior untested (AC2)
- `coverage_gaps`: Service layer dependency injection untested (AC4)

Fix plan:

- Add a test ensuring the Toolkit Menu "Back" action returns to Main Menu
- Add a test verifying the service layer correctly uses injected dependencies
- Re-run lint/tests and update Dev Agent Record + File List accordingly

## Key Principles

- Deterministic, risk-first prioritization
- Minimal, maintainable changes
- Tests validate behavior and close gaps
- Strict adherence to allowed story update areas
- Gate ownership remains with QA; Dev signals readiness via Status
