# boot

Analyze a consuming project and generate a compact set of project rules for faster future work.

## Goal

Create a small amount of durable project context as markdown rule files without exploding the number of generated files.

## Workflow

### Phase 0 - Check CLAUDE.md

The MOSK directives from `.claude/mosk/claude_boot.md` are inserted as a
**delimited block** so they can be refreshed without clobbering
project-specific instructions:

```
<!-- MOSK:DIRECTIVES:START -->
... contents of claude_boot.md ...
<!-- MOSK:DIRECTIVES:END -->
```

1. If `CLAUDE.md` does **not** exist in the project root: create it from
   `.claude/mosk/claude_boot.md`, wrapping the imported content in the
   `MOSK:DIRECTIVES` markers above.
2. If `CLAUDE.md` **exists**:
   - If the `MOSK:DIRECTIVES` markers are present, replace **only** the
     content between them with the current `claude_boot.md`. Leave
     everything outside the markers untouched.
   - If the markers are absent, **prepend** the marked block to the file
     without modifying any existing content. Never overwrite or
     paraphrase project-specific instructions already in `CLAUDE.md`.
   - If a near-duplicate of the directives exists unmarked (from an older
     boot), point it out and ask the user before removing it — do not
     delete it silently.
3. Only proceed to Phase 1 after confirming `CLAUDE.md` is present and the
   directives block is delimited by the markers.

### Phase 1 - Inspect the project

1. Read the directory structure up to 3 levels deep, excluding obvious dependency and VCS folders.
2. Read `CLAUDE.md` to understand any existing project instructions.
3. Read the main reference files that exist:
   - `README.md`
   - package and build manifests
   - primary config files
   - sample env files
4. Sample representative source files from the main layers that exist:
   - entrypoints or routes
   - services or use cases
   - models or repositories
   - frontend components, if any
   - tests

### Phase 2 - Generate base project rules

Create the `.claude/rules/` directory if it does not exist, then write these files as plain markdown (no YAML frontmatter):

- `.claude/rules/project.md` (always)
- `.claude/rules/frontend.md` (only if frontend code exists)

`project.md` should contain:
- system purpose
- stack
- architecture pattern
- folder conventions
- testing commands
- common workflows
- rules the AI should follow in this project

`frontend.md` should contain only:
- frontend stack
- component and styling conventions
- state and API call patterns
- frontend testing notes

When generating `project.md`, start from the canonical template at
`.claude/mosk/templates/project-rule-tmpl.md` and fill in the project
placeholders (`{{PROJECT_NAME}}`, `{{LANGUAGE_RUNTIME}}`, `{{ARCHITECTURE_PATTERN_AND_KEY_LAYERS}}`,
`{{FOLDER_CONVENTIONS_DISCOVERED_IN_THE_CODEBASE}}`, `{{HOW_TO_RUN_TESTS_UNIT_INTEGRATION_E2E}}`,
`{{PROJECT_SPECIFIC_AI_RULES}}`) with information discovered in Phase 1.
**Keep the MOSK-invariant sections** (Document Organization, Promotion
Convention, Agent Roles, Escalation Policy, Spec Numbering, docs/index.md)
exactly as they appear in the template — they are the framework
contract. Do not paraphrase or drop them.

### Phase 2.5 - Scaffold `docs/` structure

Create the canonical `docs/` skeleton if it does not exist. Works for
both greenfield (empty `docs/`) and brownfield (partial `docs/`). For
each path below, create only if missing — never overwrite existing files.

- `docs/discovery/` (with `README.md` explaining the folder's purpose)
- `docs/prd/` (with `index.md` placeholder if empty)
- `docs/architecture/` (with `index.md` placeholder if empty, plus `adr/` subdir)
- `docs/ui/` (with `index.md` placeholder if empty, plus `flows/` subdir)
- `docs/qa/gates/`
- `docs/specs/`

Each README.md briefly explains:

- which agent writes here (e.g., "`mosk-analyst` writes discovery artifacts here")
- the distinction between base and per-spec content (base = project-wide; per-spec = `docs/specs/{id}/<domain>/`)
- what gets promoted from spec to base at archive time (see Promotion Convention in `project.md`)

### Phase 2.6 - Docs conformance scan (greenfield **and** brownfield)

A MOSK project must never have documents lying loose in `docs/`. Run this
scan on every boot, regardless of greenfield/brownfield — even an
otherwise-empty `docs/` can contain stray files.

1. **Enumerate** everything under `docs/` and classify each entry as
   either **conformant** or **non-conformant**:
   - Conformant: lives under a canonical domain (`discovery/`, `prd/`,
     `architecture/`, `ui/`, `qa/`, `specs/`), or is `index.md` / a
     per-domain `README.md`. Resolve the canonical roots from
     `.claude/mosk/core-config.yaml` (`discovery.root`, `prd.root`,
     `architecture.root`, `ui.root`, `qa.gatesDir`, `specs.root`).
   - Non-conformant: anything else — e.g. loose files at the `docs/`
     root, legacy monoliths (`docs/prd.md`, `docs/architecture.md`),
     `docs/stories/`, `docs/epics/`, `docs/brainstorming-session-results.md`,
     `docs/front-end-spec.md`, or folders outside the canonical domains.

2. **If non-conformant content exists, do not leave it.** Resolve it in
   this order, **without running anything destructive automatically**:
   - **a) Suggest the migration script** when legacy monoliths/structures
     are present: `bash .claude/mosk/scripts/migrate-docs-structure.sh`
     (recommend `--dry-run` first). The script handles the bulk,
     mechanical moves. Stop and let the user run it.
   - **b) Hand off residuals to the organizer** for whatever the script
     cannot place mechanically (loose root files, orphan stories/epics,
     ambiguous domains): load and execute the companion prompt
     `.claude/mosk/utils/post-migration-organize.md`, which reads each
     residual, classifies it by domain heuristics, and allocates it into
     the right base domain or spec. Nothing is moved without user
     confirmation.
   - **c) Manual last mile.** For anything still unclassified, read the
     file, propose a canonical destination (base vs `specs/{id}/<domain>/`
     per the base×spec rule), and ask the user to confirm before moving.

3. The exit condition for this phase: `docs/` contains only conformant
   entries, or every remaining non-conformant file has an explicit,
   user-approved disposition. Report anything left unresolved.

After scaffolding and the conformance scan, call the
`../tasks/index-docs.md` task to generate an initial `docs/index.md`
reflecting the structure.

### Phase 3 - Suggest additional rules

Based on the project type and what was discovered in Phase 1, evaluate which additional rule files would be useful. Present each suggestion to the user and **wait for approval** before creating it.

Additional rules live in `.claude/rules/<topic>.md` as plain markdown.

Possible suggestions (evaluate relevance for the specific project):

- **coding-standards.md**: naming conventions, linting rules, code style, import ordering, file organization patterns actually found in the codebase.
- **testing.md**: test framework, how to run tests (unit, integration, e2e), coverage expectations, test file location patterns, fixtures and factories.
- **migrations.md**: how to create and run database migrations, ORM conventions, seed data, rollback procedures.
- **permissions.md**: authentication and authorization patterns, role system, middleware chains, access control conventions.
- **deploy.md**: deployment process, CI/CD pipeline, environment variables, staging vs production differences.
- **api.md**: API conventions, endpoint patterns, request/response contracts, pagination, error format.

Rules for this phase:
- Only suggest rule files that are clearly supported by evidence found in the project.
- Present each suggestion with a one-line rationale explaining why it was detected as relevant.
- The user may accept all, some, or none.
- Do not create any rule file the user did not approve.

### Phase 4 - Update CLAUDE.md

Update the project's `CLAUDE.md` file to include a project rules section so that all MOSK agents can discover and load the generated context:

1. If a `## Project Rules` section already exists, update it.
2. Otherwise, append the section below.
3. If a legacy `## Context Skills` section exists, replace it with `## Project Rules`.

Add this section:

```markdown
## Project Rules

The following project rules were generated by `/mosk-boot` and live in `.claude/rules/`:

{list each generated rule file with a one-line description of its content}

MOSK agents read every file in `.claude/rules/*.md` automatically before executing any task. Re-run `/mosk-boot` to regenerate them if the project structure changes significantly.
```

### Phase 5 - Report

Report:
- files created or updated (including `CLAUDE.md` and each `.claude/rules/*.md`)
- stack detected
- docs conformance: non-conformant entries found and their disposition (migrated, organized, manually placed, or still unresolved)
- additional rules suggested vs. approved
- areas that were not identified cleanly

## Rules

- Do not invent project conventions. Only document what is actually found.
- Never leave non-conformant documents loose in `docs/`. Always run the conformance scan and resolve or get explicit user disposition for every stray file.
- Never run `migrate-docs-structure.sh` or move/delete docs automatically. Suggest the script, hand residuals to the organizer, and confirm manual moves with the user.
- Keep each generated rule file short and prescriptive.
- Prefer one strong `project.md` rule file over many narrow rule files.
- Never create additional rule files without explicit user approval.
- Always explain why each additional rule file is being suggested.
- Write rule files as plain markdown, no YAML frontmatter.
