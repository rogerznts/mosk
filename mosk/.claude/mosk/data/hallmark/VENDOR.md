# Hallmark — vendored copy

Reference material consumed by the MOSK task `../../tasks/hallmark.md`
(agent: `../../agents/ui-expert.md`). This directory is a **vendored fork**
of an upstream project — do not hand-edit it as if it were MOSK-authored
content; see "Re-syncing" below.

## Upstream

| | |
|---|---|
| Project | [Hallmark](https://github.com/Nutlope/hallmark) — anti-AI-slop design skill |
| Author | Nutlope / Together AI |
| Licence | MIT — see `LICENSE` (preserved verbatim) |
| Version | 1.1.0 |
| Pinned ref | `aeb42fb354ff4efa36ab475773a082315a3af2ce` (2026-06-04) |
| Source path | `skills/hallmark/` |

Fetched from the repository tarball at that ref (`skills/hallmark/`, plus
`site/css/tokens.css` and `LICENSE`, which live outside the skill upstream).
`../../scripts/sync-hallmark.sh` does this for you — see "Re-syncing".

## Modifications applied to the upstream copy

These are not reapplied by a hand-written patch list: `sync-hallmark.sh`
derives them as a **diff between the pinned upstream and this directory**,
then replays that diff onto the new ref. So this section is documentation for
humans — the script stays correct even if the list below drifts. What matters
is that any change you make here becomes part of the fork's diff.

1. **`SKILL.md` → `hallmark.md`**, YAML front-matter removed. MOSK's
   `data/` and `tasks/` files carry no front-matter, and the entry point is
   reached through the task, not through skill auto-discovery. Every textual
   and link reference to `SKILL.md` across `references/` was rewritten to
   `hallmark.md`.

2. **`site/css/tokens.css` vendored** as `references/themes/tokens.css`. The
   20 named catalog themes only have concrete OKLCH values in that file, and
   upstream keeps it outside `skills/hallmark/`. The three relative-path
   forms (`../../`, `../../../`, `../../../../site/css/tokens.css`) were
   rewritten to the correct depth, and the link labels realigned.

3. **Out-of-tree references turned into upstream permalinks** — pinned to
   the ref above, so they keep resolving:
   - `docs/recipes.md`, `docs/study-examples.md` — marked *"Human-only (do
     NOT auto-load)"* upstream, so they are linked, not copied.
   - `site/examples/cobalt-01/`, `site/_tests/03-maple-bakery/`,
     `site/_tests/05-tracejam-saas/` — rendered example builds.

4. **`## MOSK integration` block added to `hallmark.md`**, right after the
   H1, between `<!-- MOSK-INTEGRATION:BEGIN -->` / `:END` markers (the H1
   attribution note uses `<!-- MOSK-HEADER:BEGIN -->` / `:END`). It maps
   Hallmark's output contract onto the MOSK document layout (`docs/ui/` vs
   `docs/specs/{id}/ui/` with `promote:`), points `design.md` at
   `docs/ui/design-system.md`, makes the pre-flight scan read
   `.claude/rules/` first, and wires the escalation policy. The markers are a
   post-sync invariant: the script fails if either block goes missing.

5. **In-place edits to the Design flow** where the upstream text hardcodes a
   project-root `design.md`: Step 0's signal list (now seven sources, headed
   by `.claude/rules/`), the "design system found" branch, the Step 5 CTA
   condition, and the Step 6 multi-format-exports bullet.

Not vendored: `docs/screenshots/` (18 JPEGs, 1.5 MB), the `site/` build,
`README.md`, `ROADMAP.md`.

## Re-syncing

```bash
bash .claude/mosk/scripts/sync-hallmark.sh --dry-run          # preview
bash .claude/mosk/scripts/sync-hallmark.sh                    # same pinned ref
bash .claude/mosk/scripts/sync-hallmark.sh --ref <sha-or-tag> # bump upstream
```

The script fetches the pinned ref, diffs it against this directory to recover
the fork's changes, fetches the new ref, replays the diff, then checks every
internal markdown link and the invariants above. A conflict leaves `.rej`
files in a preserved work directory and **does not touch the vendor**.

Copying the upstream over this directory by hand instead **erases the MOSK
integration**.
