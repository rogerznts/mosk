---
description: "Re-sincroniza o vendor do Hallmark por diff/replay contra um novo ref do upstream"
---

# Task: Sync Hallmark vendor

## Goal

Bring `.claude/mosk/data/hallmark/` up to a new upstream ref **without losing the
MOSK adaptations**. Replaces the former `sync-hallmark.sh`.

## Why this is delicate

The vendor is a **fork**, not a copy. Beyond the upstream files it carries:

- the `## MOSK integration` block in `SKILL.md`
- `references/themes/tokens.css`, which upstream keeps outside the skill
- rewritten internal links
- a renamed `SKILL.md`

Running `npx degit` over the directory erases all of that. So does copying the
new upstream on top. **Never do either.**

## Guardrails

- **Any conflict aborts without touching the vendor.** A half-applied patch is
  worse than an outdated vendor, because the next sync diffs against a state
  that is neither the fork nor upstream.
- Work entirely in a temp directory; the vendor is replaced only on a clean
  apply.
- Read `data/hallmark/VENDOR.md` first — it pins the current ref.

## Procedure

The method is **diff and replay**: extract the MOSK adaptations as a patch by
diffing upstream-at-the-old-ref against the current vendor, then reapply that
patch on upstream-at-the-new-ref.

```
old (upstream @ OLD_REF) ──diff──> cur (vendor)  =  the MOSK adaptations
                                                          │
new (upstream @ NEW_REF) <────────── apply ───────────────┘
```

**1. Read the pinned ref.** `OLD_REF` comes from `data/hallmark/VENDOR.md`. The
new ref is what the user asked for; if they gave none, this is a no-op check.

**2. Fetch both refs** into a temp dir. Use the codeload tarball, not degit —
it accepts any SHA, including commits that are not the tip of a branch:

```bash
curl -sfL "https://codeload.github.com/Nutlope/hallmark/tar.gz/<ref>" | tar -xz -C <box>
```

From each extracted tree, take `skills/hallmark/` plus the two files that live
outside it: `site/css/tokens.css` → `references/themes/tokens.css`, and
`LICENSE`. Stop if `SKILL.md` is missing — the upstream layout changed and the
rest of this procedure no longer applies.

**3. Extract the adaptations.**

```bash
git diff --no-index --no-color -M --text old cur > mosk.patch
```

An empty patch means the vendor is identical to upstream — say so, because it
usually means the adaptations were already lost.

**4. Reapply on the new ref.** Note `-p2`: `git diff --no-index old cur`
produces paths like `a/old/x` and `b/cur/x`, which is **two** components to
strip, not one.

```bash
cd new && git apply -p2 --reject --whitespace=nowarn ../mosk.patch
```

**5. On conflict, stop.** Upstream changed the very lines MOSK adapts. Keep the
work area, list every `.rej`, and hand it to the user — resolving those edits is
judgement about content, not something to guess at. The vendor stays untouched.

**6. On a clean apply:** update the pinned ref in `VENDOR.md`, replace the
vendor directory, and report how many files changed.

## Verification

After replacing, confirm internal links still resolve and that the
`## MOSK integration` block survived in `SKILL.md`. If either fails, restore and
report — a vendor that lost its integration looks fine and behaves wrong.

## Reference

`data/hallmark/VENDOR.md` — pinned ref, upstream URL, and what the fork changes.
