# boot

Analyze a consuming project and generate a compact context skill set for faster future work.

## Goal

Create a small amount of durable project context without exploding the number of generated skills.

## Workflow

### Phase 1 - Inspect the project

1. Read the directory structure up to 3 levels deep, excluding obvious dependency and VCS folders.
2. Read the main reference files that exist:
   - `README.md`
   - package and build manifests
   - primary config files
   - sample env files
3. Sample representative source files from the main layers that exist:
   - entrypoints or routes
   - services or use cases
   - models or repositories
   - frontend components, if any
   - tests

### Phase 2 - Generate compact context

Create only these skills by default:

- `.claude/skills/ctx-project/SKILL.md`
- `.claude/skills/ctx-frontend/SKILL.md` only if frontend code exists

`ctx-project` should contain:
- system purpose
- stack
- architecture pattern
- folder conventions
- testing commands
- common workflows
- rules the AI should follow in this project

`ctx-frontend` should contain only:
- frontend stack
- component and styling conventions
- state and API call patterns
- frontend testing notes

### Phase 3 - Report

Report:
- files created
- stack detected
- areas that were not identified cleanly

## Rules

- Do not invent project conventions.
- Keep each generated skill short and prescriptive.
- Prefer one strong `ctx-project` skill over many narrow context files.
