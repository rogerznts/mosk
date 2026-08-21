# checklist

Create or update a focused checklist for the active spec.

## User Input

```text
$ARGUMENTS
```

## Goal

Generate a lightweight checklist only when the user explicitly wants a structured review lens.

## Workflow

1. Resolve the active feature directory with `.claude/mosk/scripts/validate.sh prerequisites --json --paths-only`.

2. Determine the checklist domain from the request or ask one short question if it is missing.
   Supported defaults:
   - product
   - architecture
   - implementation
   - QA
   - release

3. Read only the artifacts needed for that domain.

4. Create or update `FEATURE_DIR/checklists/{domain}.md` using `.claude/mosk/templates/checklist-template.md`.

5. Keep the checklist high signal:
   - 8 to 15 items
   - one concern per line
   - mark only what the evidence supports

6. Report:
   - checklist path
   - domain
   - major open items

## Rules

- This task is optional by design.
- Do not expand it into a full audit unless the user asks.
