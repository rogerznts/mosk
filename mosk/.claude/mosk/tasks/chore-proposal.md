# chore-proposal

Scaffold a new quick-change proposal using Plan Mode.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Guardrails

- Favor straightforward, minimal implementations first and add complexity only when it is requested or clearly required.
- Keep changes tightly scoped to the requested outcome.
- Identify any vague or ambiguous details and ask the necessary follow-up questions before editing files.

## Steps

1. Inspect existing quick changes in `./docs/changes/` (if present) and related code/docs to ground the proposal in current behavior.
2. Choose a unique verb-led `change-id` and scaffold `proposal.md`, `tasks.md`, and `design.md` (when needed) under `./docs/changes/<id>/`.
3. Use Plan Mode to refine scope, constraints, and execution order before implementation.
4. Draft `proposal.md` with context, objective, expected impact, and explicit acceptance criteria.
5. Draft `tasks.md` as an ordered list of small, verifiable work items that include validation (tests/tooling) and dependencies.
6. Add `design.md` only when the change spans multiple systems or needs trade-off documentation.
7. Before handoff, ensure docs and tasks are consistent and that no step depends on external CLIs.

## Reference

- Use direct file reads under `./docs/changes/<id>/` as the source of truth.
- Re-run Plan Mode if scope changes during proposal drafting.
- Explore the codebase with `rg <keyword>`, `ls`, or direct file reads so proposals align with current implementation realities.
