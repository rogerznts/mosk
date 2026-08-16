# specify

Create or update the active `spec.md` from a natural-language request.

## User Input

```text
$ARGUMENTS
```

Use the input as the source of truth for the requested change.

## Goal

Produce a short, implementation-safe specification that is ready for planning without turning every unknown into a blocker.

Use `.claude/mosk/data/adaptive-work-contract.md` to distinguish bounded from
material ambiguity. When clarification is material, collect every blocking
question first and ask them in one grouped round.

## Workflow

1. Determine the spec type:
   - `feature`
   - `fix`
   - `hotfix`
   - `gmud`
   - `refactor`
   - `experimental`
   Use a reasonable default from the request. Ask only if the choice materially changes urgency or rollout.

2. Determine the active branch and spec path.
   - Check the current Git branch first.
   - **If the current branch is NOT `main`/`master`/`develop`/`dev`**: you are already on a spec branch or environment branch. **Do NOT create a new branch. Do NOT run `create-new-feature.sh`.** Reuse the current branch and resolve the spec folder **by numeric prefix**, never by string equality:
     ```bash
     source .claude/mosk/scripts/common.sh
     find_feature_dir_by_prefix "$(get_repo_root)" "$(get_current_branch)"
     ```
     Branch and folder are deliberately different strings (ADR-0017): the branch is `{tipo}/{NNN}-{nome}` (`feature/012-checkout-coupon`) and the folder is flat, `docs/specs/{NNN}-{tipo}-{nome}` (`012-feature-checkout-coupon`). Concatenating the branch into the path yields `docs/specs/feature/012-checkout-coupon/` — a directory that never exists.
   - **Only if the current branch IS a base branch (`main`, `master`, `develop`, `dev`)**: a new feature branch is needed. **Before creating it, you MUST ask the user for explicit confirmation.** Present:
     - the proposed branch name, in the canonical shape `{tipo}/{NNN}-{nome}` (e.g. `feature/012-checkout-coupon`); the matching folder will be `docs/specs/012-feature-checkout-coupon`
     - the likely next number (a preview only — check `docs/specs/` for the highest existing prefix; the script is authoritative)
     - wait for a clear "yes" / confirmation before proceeding
   - Only after user confirmation, run `.claude/mosk/scripts/create-new-feature.sh --json` once. The script picks the next number globally and **atomically reserves it on `origin`** (an immutable `refs/spec-numbers/<NNN>` ref) before creating the branch, so two people creating specs at the same time can never end up with the same number. The final number may differ from your preview if a concurrent creation won the race — always trust the JSON output, not the preview.
   - Parse the JSON output for the final branch and spec path.
   - **Never create a branch automatically. Branch creation always requires user approval.**

3. Load `.claude/mosk/templates/spec-template.md`.

4. Write or update `spec.md` with these minimum outcomes:
   - problem or opportunity
   - users or actors
   - core scenarios
   - functional requirements
   - edge cases
   - assumptions and defaults chosen
   - success criteria

5. Use defaults aggressively.
   - Only insert `[NEEDS CLARIFICATION: ...]` when the answer changes scope, risk, UX, or public behavior.
   - Hard limit: 3 markers total.
   - Do not start a second clarification round. After the grouped answer,
     record safe defaults or report the remaining real blocker.

6. Do not generate checklists automatically.
   - `clarify`, `analyze`, and `checklist` are optional follow-up steps.

7. Report:
   - branch name (`{tipo}/{NNN}-{nome}`)
   - spec path (flat folder — differs from the branch, by design)
   - chosen spec type
   - clarification marker count
   - recommended next step:
     - `plan` when the spec is ready
     - `clarify` only when critical markers remain

8. **Refresh the docs index.** As the final step, execute
   `../tasks/index-docs.md` with `docs/` as the target. This adds the
   new spec to the `Active Specs` table in `docs/index.md`. Automatic
   refresh — do not ask the user unless there are conflicts.

## Rules

- Keep the spec readable by both product and engineering.
- Do not leak implementation detail unless the request explicitly requires it.
- Do not ask the user to repeat the original request unless the input is empty.
- Refreshing the index and recording a valid reversible transition do not need
  intermediate confirmation. Branch creation keeps its explicit approval.
