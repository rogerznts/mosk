---
name: tea-open-fast-pr
description: "Full flow from scratch using `tea` CLI: asks branch type, creates and checkouts the branch (from stable branch for hotfix, from integration branch otherwise), commits pending changes, pushes, and opens a PR on Gitea."
---

# Open Fast PR (tea)

Your goal is to guide the user through the **full flow**: branch creation → commit → push → Pull Request, all in a single command. This extends `/tea-open-pr` by handling everything from the branch creation onward.

## Prerequisites

`tea` must be configured with a login for this server. If not yet done, run:

```bash
tea login add --name=<alias> --url=<gitea-url> --token=<your-token>
```

When run inside a git repository that has a Gitea remote, `tea` auto-detects the login and repo — no flags or env vars needed.

---

## Workflow

### Step 1 — Ask for branch type and name

Ask the user **two questions in a single message**:

1. What type of branch is this? Options: `feature`, `bugfix`, `hotfix`
2. What should the branch name be? (without the prefix — e.g., `login-fix`)

Compose the full branch name as `<type>/<name>` (e.g., `hotfix/login-fix`).

> **For a MOSK spec, do not name the branch by hand.** Run
> `bash .claude/mosk/scripts/create-new-feature.sh` instead — it reserves the
> spec number atomically and produces `{tipo}/{NNN}-{nome}` plus the matching
> flat folder. This skill is for ordinary branches that are not specs.

Also confirm the branch conventions with the user if unknown:
- **Stable branch** (production): typically `main` or `master`
- **Integration branch** (staging/QA): typically `hml`, `develop`, or `staging`

---

### Step 2 — Create and checkout the branch

Based on the type:

- **hotfix** → base is the stable branch (e.g., `main`). Run:
  ```bash
  git stash
  git fetch origin
  git checkout main
  git pull origin main
  git checkout -b <branch-name>
  git stash pop
  ```

- **feature / bugfix** (or any other type) → base is the integration branch (e.g., `hml`). Run:
  ```bash
  git stash
  git fetch origin
  git checkout hml
  git pull origin hml
  git checkout -b <branch-name>
  git stash pop
  ```

> Replace `origin` with the actual remote name used in the repository.
> Never skip the checkout and pull of the base branch before creating the new one.
> If `git stash pop` results in a merge conflict, show the diff to the user and ask which version to keep before proceeding.

---

### Step 3 — Understand the pending changes

Run:

```bash
git status
git diff
```

- Read and summarize the changes for the user.
- Alert if debug code is present (`console.log`, `var_dump`, `dd()`).
- If there is nothing to commit (clean working tree), inform the user and stop.

---

### Step 4 — Commit

Stage and commit all changes:

```bash
git add -A
git commit -m "<conventional-commit-message>"
```

- Generate the commit message in Conventional Commits format (e.g., `fix(login): handle locked account redirect`).
- Show the proposed message to the user and commit.
- Do not skip hooks (`--no-verify`).

---

### Step 5 — Push the branch

```bash
git push -u origin <branch-name>
```

Replace `origin` with the actual remote name. Confirm push succeeded before proceeding.

---

### Step 6 — Identify the branches and type (for PR)

- The **source** (head) is the branch just created and pushed.
- Use the branch prefix to determine targets:
  - **Feature / Bugfix** → single PR to the integration branch
  - **Hotfix** → two PRs: first to the stable branch, second to the integration branch

---

### Step 7 — Read the diff (for PR text)

```bash
git log <integration-branch>..<head> --oneline
git diff <integration-branch>..<head> --stat
```

(Use `<stable-branch>..<head>` for hotfix.)

Alert the user if debug logs (`console.log`, `var_dump`, `dd()`) are present.

---

### Step 8 — Generate the PR text

**Title:** Conventional Commits format (e.g., `feat(module): short description`).

**Body (Standard PR — Feature / Bugfix / Hotfix → stable branch):**

```
## Summary

- <bullet: what this PR does, high level>

## Details

**How:** <explanation of how the changes were implemented>

- <bullet per relevant change group>

**Why:** <motivation, business rule, or problem being solved>

## Impact

- <bullet: effect on the user or system>
```

**Body (Hotfix → integration branch — always use exactly this):**

```
Applying hotfix changes to the integration branch.
```

- All text must be in English.
- Be clear and professional.

---

### Step 9 — Determine the label

Run to list available labels:
```bash
tea labels list
```

Auto-suggest based on branch prefix:

| Branch prefix | Suggested label |
|---------------|-----------------|
| `feature/`    | `Kind/Feature` (or equivalent) |
| `bugfix/`     | `Kind/Bug` (or equivalent) |
| `hotfix/`     | `Kind/Hot` (or equivalent) |

- Match against the actual labels returned by `tea labels list`.
- If a clear match exists, inform the user and proceed. If not, show the list and ask.
- The same label applies to **both PRs** on a hotfix.

---

### Step 10 — Determine the assignee

Ask the user who to assign, or skip if unneeded.

---

### Step 11 — Create the PR(s)

**Feature / Bugfix — single PR to integration branch:**
```bash
tea pr create \
  --title "<title>" \
  --description "<body>" \
  --base <integration-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

**Hotfix — two PRs:**

First, PR to stable branch:
```bash
tea pr create \
  --title "<title>" \
  --description "<standard body>" \
  --base <stable-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

Then, PR to integration branch:
```bash
tea pr create \
  --title "<title>" \
  --description "Applying hotfix changes to the integration branch." \
  --base <integration-branch> \
  --labels "<label-name>" \
  --assignees "<username>"
```

Use `--login <alias>` if you have multiple logins configured.

---

### Step 12 — Return the URL(s)

`tea pr create` outputs the PR URL on success. Show it to the user:

- **Feature / Bugfix:** the single PR URL
- **Hotfix:** both PR URLs with their respective targets

---

## Notes

- `tea` resolves label names and assignee usernames automatically — no ID lookups needed.
- `tea` auto-detects server and repo from the git remote when run inside the repository.
- Replace `origin` with the actual remote name used in the repository (check with `git remote -v`).
- Never skip the base branch checkout/pull before creating the new branch.
- Never use `--no-verify` on commits.
- For hotfixes, both PRs share the same title and label, but have different bodies and base branches.
- If the working tree is clean after branch creation, stop and inform the user — there is nothing to commit.
- If `git stash pop` causes a merge conflict, surface the diff to the user and ask which version to keep before doing anything else.
