# clarify

Resolve only the critical ambiguities in the active `spec.md`.

## User Input

```text
$ARGUMENTS
```

## Goal

Reduce rework risk without turning clarification into a long interview.

## Workflow

1. Run `.claude/mosk/scripts/validate.sh prerequisites --json --paths-only` once and parse:
   - `FEATURE_DIR`
   - `FEATURE_SPEC`

2. Read `FEATURE_SPEC` and identify ambiguities that would materially change:
   - scope
   - UX behavior
   - data shape
   - security or compliance
   - public API or contract behavior

3. If no critical ambiguities remain, report that the spec is ready and suggest `plan`.

4. If clarification is needed:
   - ask at most 3 questions total
   - ask them in one batch when possible
   - include a recommended answer when you have a safe default

5. Update the spec directly after the user answers:
   - replace vague text instead of duplicating it
   - add a short `## Clarifications` section only if needed

6. Report:
   - questions asked
   - sections updated
   - remaining ambiguity, if any
   - recommended next step

## Rules

- Do not ask about low-impact preferences.
- Use short questions and short expected answers.
- Keep clarification optional; if the remaining ambiguity is low risk, say so.
