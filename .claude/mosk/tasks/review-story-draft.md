# review-story-draft

Independently review a draft story before implementation using the canonical
readiness criteria.

## Dependencies

```yaml
checklists:
  - story-readiness-checklist.md
templates:
  - story-tmpl.yaml
data:
  - output-contract.md
```

## Workflow

1. Read `.claude/mosk/core-config.yaml`; resolve the requested story, parent
   epic/spec, story template and only its cited architecture/rules.
2. Check structure and placeholders against `story-tmpl.yaml`.
3. Execute every item in
   `.claude/mosk/checklists/story-readiness-checklist.md` against evidence in the
   draft and accessible sources.
4. Verify specifically:
   - every AC is testable and covered by tasks;
   - paths and technical claims match their cited sources;
   - UI, security, data and operational concerns are present when applicable;
   - dependencies, sequence, rollback and unknowns are actionable;
   - no unsupported decision is presented as fact.
5. Emit `READY`, `NEEDS_REVISION` or `BLOCKED` as defined by the checklist.
   Follow `output-contract.md`: findings are stable, standalone blocks with
   evidence, impact and the smallest useful correction.
6. Do not rewrite the story unless explicitly asked. When asked, change only the
   cited gaps and rerun the same checklist.

## Output

- result and finding counts;
- one block per gap, ordered by blocking impact;
- sources checked;
- direct next step.

The shared checklist is the only readiness criteria source; do not duplicate it
inside this task.
