# assess-security

Full-codebase security audit. Same methodology and taxonomy as `security-review.md`, but the scope is the **whole repository**, not just the diff. On demand and outside the happy path — it is more expensive, so only run it when the user asks for a broad audit (new project onboarding, pre-release hardening, periodic review).

## Dependencies

```yaml
data:
  - output-contract.md # vocabulário de ids + formato de achado (obrigatório)
  - adaptive-work-contract.md
scripts:
```

## Goal

Produce a prioritized security report covering the codebase as it stands today, with the same high-signal / low-false-positive bar as the diff-aware review.

## Scope

The entire codebase (respecting any `exclude` hints in `.claude/rules/*.md`, and skipping vendored/generated code and test-only files). This is not tied to a branch diff.

## Workflow

Classify the audit before loading broad context, applying the canonical
`.claude/mosk/data/adaptive-work-contract.md`. A whole-codebase audit requests
at least `elevated`; use the returned context, validation and specialist floors
without copying their rules here. Reclassify upward when a higher-risk entry
point or wider trust boundary is discovered. The explicit audit request remains
valid regardless of the calculated minimum, and the security assessment stays
independent from implementation and QA.

Follow the same phases as `../tasks/security-review.md`:

1. **Phase 1 — Repository Context Research**: frameworks, secure patterns, threat model.
2. **Phase 2 — Comparative Analysis**: across the codebase, find where secure patterns are and are not applied consistently.
3. **Phase 3 — Vulnerability Assessment**: trace data flow across modules, focusing on entry points (routes, handlers, CLI, message consumers) down to sensitive sinks.
4. **Phase 4 — Severity and confidence**: same HIGH/MEDIUM/LOW + confidence 0–1 scale; report only confidence > 0.8.
5. **Phase 5 — False-positive filtering**: apply the same 17 exclusion rules and file-type awareness as `security-review.md`.
6. **Phase 6 — Write the report**:
   - Resolve `qa.qaLocation` from `.claude/mosk/core-config.yaml`.
   - Write to `{qa.qaLocation}/security/security-audit-{date}.md` (use the date from the environment, ISO `YYYYMMDD`).
   - Same finding form and summary as `security-review.md`, i.e. `../data/output-contract.md`: one block per finding, never a table row. Group the blocks by module/area when the codebase is large.
   - Because this is not tied to a single change, replace the gate verdict line with an **overall risk posture**: `RISK: LOW | MEDIUM | HIGH`.

## Rules

- Prioritize ruthlessly: surface the exploitable findings first; do not pad the report with hygiene notes.
- Cap the deep-dive to the highest-risk entry points first; if you must stop early, say what was and was not covered.
- Not a pipeline phase — do not touch `spec-meta.yaml`.
- Not hardened against prompt injection — run only on trusted code.
