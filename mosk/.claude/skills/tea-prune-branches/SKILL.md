---
name: tea-prune-branches
description: Fetches with prune and removes local branches whose remote tracking branch has been deleted.
---

# Prune Branches

Your goal is to synchronize the local repository with the remote by pruning stale remote-tracking refs and deleting any local branches that no longer have a corresponding remote branch.

## Workflow

### Step 1 — Detect the remote name

Run:
```bash
git remote -v
```

Identify the primary remote name (commonly `origin`). Use it in all subsequent commands.

---

### Step 2 — Sync main integration branches

Before anything, update the main branches so git's merge-base calculations are accurate (this prevents false "unmerged" errors on `-d`).

Detect which main branches exist and update them:
```bash
git fetch --prune
git checkout main && git pull <remote> main
git checkout <integration-branch> && git pull <remote> <integration-branch>
```

Common integration branch names: `hml`, `develop`, `staging`. Confirm with the user if unsure.

Return to the original branch after pulling:
```bash
git checkout <original-branch>
```

Report any deleted remote refs shown in the fetch output.

---

### Step 3 — Find stale local branches

Run:
```bash
git branch -vv | grep ': gone]'
```

List all local branches whose upstream is marked as `gone`.

---

### Step 4 — Delete stale local branches

For each branch found in Step 3, run:
```bash
git branch -d <branch-name>
```

Use `-d` (safe delete). If a branch cannot be deleted with `-d` due to unmerged commits, **do not force-delete** — report it to the user and ask how to proceed.

---

### Step 5 — Report results

Summarize the result:
- Which remote refs were pruned
- Which branches (if any) could not be deleted and why

Then, always end with an explicit list of deleted local branches:

```
Deleted branches:
  - <branch-name>
  - <branch-name>
```

If no branches were deleted, say: `No local branches to delete.`
