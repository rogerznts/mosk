# create-story

Create a formal, implementation-ready story for an existing project from the
best available MOSK context.

## Dependencies

```yaml
templates:
  - story-tmpl.yaml
checklists:
  - story-readiness-checklist.md
```

## Workflow

1. Read `.claude/mosk/core-config.yaml`; resolve the active spec and its
   `stories/` directory.
2. Select the source in order: spec/epic, canonical PRD and architecture,
   boot-generated project rules, feature-scoped artifacts, then explicit user
   material. Do not depend on an obsolete task path as a context format.
3. Identify one story. Gather existing behavior, integration points, verified
   project patterns, constraints and known risks. Ask at most one grouped round
   for missing decisions that would materially change the result.
4. Populate `story-tmpl.yaml` with:
   - user/value statement and explicit scope;
   - observable acceptance criteria, including compatibility where applicable;
   - implementation tasks mapped to ACs;
   - verified technical guidance and source citations;
   - test strategy, risks, mitigation and rollback.
5. Keep unknowns explicit and add bounded exploration tasks when evidence can be
   discovered during implementation. Do not invent architecture.
6. Run `.claude/mosk/checklists/story-readiness-checklist.md`; fix supported
   gaps and leave decision gaps visible.
7. Save inside `{specs.root}/{current_spec_id}/stories/` using the existing
   numbering convention. Report path, sources, integration points, risks and
   readiness result.

`create-story` emits the formal story. Use `enrich-story` when an existing draft
needs deeper verified Dev Notes.
