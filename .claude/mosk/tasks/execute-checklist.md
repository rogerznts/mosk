# execute-checklist

Validate a target artifact against one explicit checklist.

## Workflow

1. Resolve the checklist named by the caller under
   `.claude/mosk/checklists/`. If it was not named, infer it only when exactly
   one checklist is referenced by the current task; otherwise ask which target
   and checklist to use.
2. Read the checklist's required artifacts and the target evidence. Missing
   evidence is visible; do not infer a pass.
3. Process all sections in one pass by default. Work section by section only
   when the user explicitly requests an interactive review.
4. Mark each item:
   - `PASS`: evidence clearly satisfies it;
   - `FAIL`: evidence contradicts it or a required element is absent;
   - `PARTIAL`: some but not all evidence exists;
   - `N/A`: not applicable, with reason.
5. Report overall result, counts by section, failed/partial items with evidence,
   and the smallest useful correction. Never replace evidence with a subjective
   confidence score.

Checklist execution validates artifacts; it does not silently modify them.
