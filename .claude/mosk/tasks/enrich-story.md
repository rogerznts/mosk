# enrich-story

Enrich an existing story with verified technical context until it is ready for
implementation. This task does not create product or architecture decisions.

## Dependencies

```yaml
checklists:
  - story-readiness-checklist.md
templates:
  - story-tmpl.yaml
```

## Workflow

1. Read `.claude/mosk/core-config.yaml`; resolve the active spec and its
   `stories/` directory. Use the story supplied by the user or the next draft in
   that directory. Do not advance to another epic without explicit direction.
2. Read the story, parent epic/spec and only the architecture/rules relevant to
   its scope. Resolve architecture files through `docs/architecture/index.md`,
   then feature-scoped `architecture/`; never assume a filename exists.
3. Add verified context to `Dev Notes`:
   - previous work and dependencies;
   - relevant models, APIs, UI contracts and integration points;
   - exact file locations and project conventions;
   - testing, security and operational constraints.
4. Cite every technical claim with its real source and section. If guidance is
   absent, say so; do not invent a library, pattern or decision.
5. Refine `Tasks / Subtasks` so every AC has an actionable implementation and
   validation path. Keep the story self-contained without copying whole source
   documents.
6. Execute `.claude/mosk/checklists/story-readiness-checklist.md`. Fix gaps that
   are supported by existing evidence. Leave product, UX or architecture
   decisions explicit and route them through the normal human escalation.
7. Save the story as `Draft` and report path, sources added, readiness result and
   unresolved gaps.

## Rules

- `create-story` emits the formal story; `enrich-story` prepares it for dev.
- A previous incomplete story is a visible dependency, not something to skip.
- References must be specific and accessible; summaries replace treasure hunts.
- The shared checklist is the only readiness criteria source.
