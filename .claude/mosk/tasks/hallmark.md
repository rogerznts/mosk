# Task: Hallmark

<!-- Capability: complete-ui-delivery -->

Run the Hallmark anti-slop design system — structural variety, not just visual polish.

## When to use

- User invokes `hallmark` by name, with or without a verb
- User asks for a new page, landing page, or app UI and wants it to not read as AI-generated
- User wants an existing interface scored against a named anti-pattern list (`audit`)
- User wants an interface rebuilt with a different structural fingerprint (`redesign`)
- User pasted a screenshot or URL of a design they admire and wants its DNA (`study`)

Not for this task: structure and behavior questions (user flows, information
architecture, wireframes) — those belong to `/mosk-ux-expert`. Backend, data and
business rules belong to `/mosk-dev`.

## Dependencies

```yaml
data:
  - hallmark/hallmark.md          # entry point: MOSK integration + the full design flow
  - hallmark/references/          # 105 files, loaded on demand — see Loading discipline
  - hallmark/VENDOR.md            # upstream ref, licence, list of MOSK modifications
```

Resolved path: `.claude/mosk/data/hallmark/`.

## Process

1. **Load `hallmark/hallmark.md` in full.** Read its `## MOSK integration` block
   first — it is what maps Hallmark's output onto this project's `docs/` layout.
   Everything after that block is upstream Hallmark, read through those rules.

2. **Detect the verb.**

   | Input | Route |
   |---|---|
   | `hallmark <target>` / no verb / a build request | Design flow (default) |
   | `hallmark audit <target>` | `references/verbs/audit.md` — score only, **never edit** |
   | `hallmark redesign <target> [--mood <name>]` | `references/verbs/redesign.md` |
   | `hallmark study <screenshot \| URL>` | `references/study.md` — **read it before extracting anything** |

   A bare verb with no `hallmark` prefix (`redesign src/App.tsx`, `audit page.css`)
   is ambiguous with the classic `webdesign-*` tasks — ask one line before routing
   (see Rules).

3. **Check scope before the page flow.** A brief naming a single element (button,
   input, card, modal, …) routes to the Component-scope flow in `hallmark.md`, not
   the page flow. Component-scope skips macrostructure, nav/footer archetypes and
   project memory, and hardens the 8-state requirement.

4. **Run the flow as specified in `hallmark.md`.** Do not compress it: the
   pre-flight block, the design-context question, the stated macrostructure /
   theme / nav / footer picks, the Step 5 preview and the Step 7 slop test are
   accountability steps, not ceremony. Skipping them is what the system exists to
   prevent.

5. **Write the artifacts to the MOSK path.** Code goes where the brief points.
   Design documents follow `hallmark.md` § MOSK integration: `docs/ui/` normally,
   `docs/specs/{id}/ui/` with `promote:` front-matter when a spec is active.

6. **Deliver every requested artifact completely.** Count files/components before
   building and cross-check the same count before delivery. Do not replace code
   with `...`, TODOs, “same as above” or prose describing omitted sections. If a
   response limit is reached, pause at a clean file/section boundary and identify
   the exact remaining artifact. This rule does not alter Hallmark's legitimate
   visual menus, navigation or macrostructure choices.

## Loading discipline

The reference body is ~675 KB. Loading it whole is the single largest avoidable
cost of this task, and `hallmark.md` § 3 is explicit about what to read when.
The shape:

- **Eager, 1–2 files** — the genre file picked at Step 1; the theme spec at
  `references/themes/<theme>.md` when one exists (most themes have none).
- **Index, then one pick** — read `references/macrostructures.md` (slim index),
  then load only `references/macrostructures/<NN-slug>.md`. Same for
  `references/component-cookbook.md` → only the picked
  `references/components/<code>-<slug>.md` files (5–7 per build).
- **Every build** — `typography.md`, `color.md`, `layout-and-space.md`,
  `motion.md`, `copy.md`, `anti-patterns.md`.
- **Only at Step 7** — `slop-test.md`. It informs fixes, not generation.
- **Never auto-load** — the whole cookbook, the whole macrostructure catalogue,
  or more than one archetype per category.

The 20 catalog themes get their concrete OKLCH values from
`references/themes/tokens.css`.

## Rules

- **Disambiguate a bare verb once.** `redesign X` and `audit X` without the
  `hallmark` prefix collide with `webdesign-redesign.md`. Ask a single line —
  *"Hallmark (macroestrutura + 58 gates) ou o redesign clássico?"* — and route on
  the answer. With the prefix, run Hallmark directly and do not ask.
- **Hallmark's rules override the agent baseline while this task is loaded.** The
  `## Core design philosophy` in `ui-expert.md` bans display serifs, bans `Inter`
  and assumes React + Tailwind; Hallmark uses display serifs in six themes, uses
  Inter Tight in `modern-minimal`, and emits framework-appropriate code including
  plain HTML + CSS. That is intended — see `ui-expert.md` § Guardrails.
- **`audit` never edits.** It returns a ranked punch list. Fixing is a separate
  request.
- **`study` extracts structure, never pixels.** Run the refusal heuristics in
  `references/study.md` *before* fetching anything: it refuses template
  marketplaces, other people's live sites without attestation, and non-public or
  internal network targets. On an auth wall, SPA shell or unreadable response,
  fall back to asking for a screenshot — never degrade silently.
- **Honest copy.** Never invent a metric, a testimonial, a logo or a customer
  count. Use the user's real numbers, a labelled placeholder, or a different
  macrostructure.
- **Never bulldoze a codebase.** State the files you expect to create/modify
  before editing. Deletions need explicit confirmation. An existing global
  stylesheet is append-only.
- **`.hallmark/log.json` and `.hallmark/preflight.json` stay at the project
  root.** They are machine state, not documentation — they do not move into
  `docs/`.
- **Do not hand-edit `.claude/mosk/data/hallmark/`.** It is a vendored fork; use
  `.claude/mosk/scripts/sync-hallmark.sh` to update it. See `hallmark/VENDOR.md`.
