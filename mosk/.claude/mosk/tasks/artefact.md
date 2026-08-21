# artefact

Create a complementary addendum ("artefact") for an **active** spec —
a small, planned scope addition that the user/customer asked for
during the spec's lifecycle, without opening a new branch or new spec.

## User Input

```text
$ARGUMENTS
```

Use the input as the source of truth for the requested addendum.

## Goal

Produce a minimal, implementation-ready addendum that lives inside the
active spec's folder, carries its own acceptance criteria, and has its
own tasks file so dev and QA can treat it as an independent unit of
work — without touching the parent spec's `spec.md`, `plan.md`,
`tasks.md`, or `gate.yaml`.

## Workflow

1. Resolve the active spec.
   - Run `bash .claude/mosk/scripts/validate.sh prerequisites --json --paths-only` to obtain `FEATURE_DIR` and `BRANCH`.
   - If the current branch is a base branch (`main`/`master`/`develop`/`dev`), stop with a clear message: artefacts can only be created on an active spec branch. Suggest the user switch to the spec branch first.

2. Read `<FEATURE_DIR>/spec-meta.yaml` and check `status:`.
   - **If `status: archived`** → **stop**, do **not** create files, do **not** change metadata. Emit the block below and exit:

     > **Esta spec já foi arquivada — precisamos abrir outra**
     > - O que apareceu: a spec pai está arquivada, e arquivo não se altera. Um adendo aqui quebraria isso.
     > - O caminho: abrir uma spec nova, ligada a esta.
     > - Prompt pronto: `bash .claude/mosk/scripts/create-new-feature.sh --type extension --extends <spec-id> "<descrição>"`
     > - Onde o resultado fica: uma spec `extension` nova, ligada a `<spec-id>` pelo campo `extends:` do `spec-meta.yaml`.
     > - Quando voltar: `/mosk-po specify` no branch novo, para detalhar a extensão.

   - **If `status: active`** → continue.

3. Determine the next artefact number.
   - List `<FEATURE_DIR>/artefacts/*.md` excluding files matching `*-tasks.md`.
   - Next number = count + 1, zero-padded to 3 digits (`001`, `002`, …).

4. Pick a short slug from the user input.
   - Lowercase, kebab-case, 2-4 meaningful words. Keep under ~40 chars.

5. Ensure the folder exists: `mkdir -p <FEATURE_DIR>/artefacts/`.

6. Generate the artefact document.
   - Load `.claude/mosk/templates/artefact-tmpl.md`.
   - Write `<FEATURE_DIR>/artefacts/<NNN>-<slug>.md` filling: title,
     `artefact_number`, `slug`, `parent_spec`, `created_at` (ISO 8601
     UTC), `status: draft`, context, scope, 1-3 acceptance criteria,
     out of scope, dependencies, notes.
   - Use defaults aggressively. Only add `[NEEDS CLARIFICATION: ...]`
     markers when the answer would change scope, risk, UX, or public
     behavior. Hard limit: 2 markers.

7. Generate the tasks file.
   - Load `.claude/mosk/templates/artefact-tasks-tmpl.md`.
   - Write `<FEATURE_DIR>/artefacts/<NNN>-<slug>-tasks.md` with
     concrete tasks derived from the acceptance criteria. Use IDs
     `A001`, `A002`, … (the `A` prefix distinguishes from parent's
     `T###`).

8. Update `<FEATURE_DIR>/spec-meta.yaml`.
   - Append an entry to the `artefacts:` list (initialize the list if
     it does not exist yet):

     ```yaml
     artefacts:
       - number: "<NNN>"
         slug: "<slug>"
         created_at: "<ISO 8601 UTC>"
         status: draft
     ```

   - Bump `last_phase_change` to now.
   - **Do NOT change** `current_phase` — the parent spec keeps its
     phase. The artefact has its own lifecycle.

9. Detect escalation signals and emit the standard "Escalation
   suggested" block (from `po.md`) **without invoking any other
   agent**:
   - Addendum changes PRD scope → recommend `/mosk-pm`, output target
     `<FEATURE_DIR>/artefacts/<NNN>-<slug>-prd-delta.md`.
   - Addendum requires architectural decision → recommend
     `/mosk-architect`, output target `<FEATURE_DIR>/architecture/`.
   - Addendum depends on missing UX flow → recommend
     `/mosk-ux-expert`.
   - Addendum needs premium visual/design system piece → recommend
     `/mosk-ui-expert`.

   Wait for the user's decision (`go`/`escalate`/`skip`).

10. Refresh the docs index.
    - Execute `../tasks/index-docs.md` with `docs/` as the target.
      Automatic refresh — do not ask the user unless there are
      conflicts.

11. Report:
    - artefact path: `<FEATURE_DIR>/artefacts/<NNN>-<slug>.md`
    - tasks path: `<FEATURE_DIR>/artefacts/<NNN>-<slug>-tasks.md`
    - acceptance criteria count
    - clarification marker count
    - recommended next step:
      - **2 or more ACs**, **or** multiple areas touched (e.g. both
        backend + frontend) → suggest
        `/mosk-sm enrich-story <FEATURE_DIR>/artefacts/<NNN>-<slug>-tasks.md`
        for dev-readiness refinement.
      - **Otherwise** → suggest
        `/mosk-dev implement <FEATURE_DIR>/artefacts/<NNN>-<slug>-tasks.md`
        directly.

## Rules

- **Never** create an artefact in an archived spec. Always escalate to
  a new `extension` spec via `create-new-feature.sh --type extension
  --extends <spec-id>`.
- **Never** modify the parent spec's `spec.md`, `plan.md`, `tasks.md`,
  or `gate.yaml`. The artefact is self-contained.
- Keep the artefact minimal: target 1-3 acceptance criteria. If scope
  is broader, suggest opening a new spec instead.
- Each artefact runs its own dev → QA cycle independently of the
  parent's progress.
- The `promote:` front-matter is **optional**. Use it only when the
  artefact produces canonical content (ADR, base flow, etc.) that
  should land in `docs/<domain>/` at archive time — same convention as
  other per-spec artefacts.
- Branch creation is **never** part of this task. The artefact reuses
  the parent spec's branch.
- Never invoke another agent automatically. Always emit the
  escalation block (`../templates/escalation-block-tmpl.md`) and wait for user confirmation.

## Reference

- Parent spec metadata schema: `.claude/rules/project.md` (Spec
  Numbering section).
- Promotion convention: `.claude/rules/project.md` (Promotion
  Convention).
- Escalation block format: `.claude/mosk/templates/escalation-block-tmpl.md`.
- Templates: `.claude/mosk/templates/artefact-tmpl.md`,
  `.claude/mosk/templates/artefact-tasks-tmpl.md`.
