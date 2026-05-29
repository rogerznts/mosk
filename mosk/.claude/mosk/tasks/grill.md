# grill

Stress-test a plan or design by interviewing the user relentlessly until you reach shared understanding — challenging it against the project's documented domain language and decisions, and updating that documentation inline as decisions crystallize.

## User Input

```text
$ARGUMENTS
```

## Goal

Surface and resolve every consequential design decision *before* it is committed to an ADR, plan, or implementation — walking the decision tree branch by branch, resolving dependencies between decisions one at a time, while sharpening terminology against the project's glossary and capturing durable decisions as ADRs.

This is the deliberate opposite of `clarify` (which asks at most 3 questions and stays light). Use `grill` when the user explicitly wants to be challenged.

## Workflow

1. Identify the target under scrutiny: the active `spec.md`/`plan.md`, an existing `docs/architecture/` doc, or a design described inline in `$ARGUMENTS`. If unclear, ask once which artifact to grill.

2. **Build domain awareness.** Before grilling, load the existing language and decisions so you can challenge against them:
   - Read every file in `.claude/rules/*.md` (durable project context).
   - Read the glossary if present: `docs/architecture/glossary.md` (base) or `docs/specs/{id}/architecture/glossary.md` (when a spec is active).
   - Skim existing ADRs in `docs/architecture/adr/` (and `docs/specs/{id}/architecture/` for the active spec).
   - Explore the codebase to ground terms and claimed behavior in real code.

3. Build the decision tree: the open technical decisions implied by the target and how they depend on each other (stack, boundaries, data shape, contracts, failure modes, tradeoffs).

4. Walk the tree **one question at a time**, waiting for feedback before continuing:
   - Ask a single question, ordered so dependencies resolve before dependents.
   - Always include your **recommended answer** with a one-line rationale.
   - If a question can be answered by reading the codebase, explore the codebase instead of asking.
   - Use the user's answer to prune or expand the remaining branches.

   While grilling, actively:
   - **Challenge against the glossary.** If a term conflicts with the documented definition, call it out: "the glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"
   - **Sharpen fuzzy language.** When a term is vague or overloaded, propose a precise canonical one: "you say 'account' — Customer or User? Those are different things."
   - **Probe with concrete scenarios.** Invent edge-case scenarios that force precision about the boundaries between concepts.
   - **Cross-reference with code.** When the user states how something works, check whether the code agrees and surface contradictions: "your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

5. **Update the glossary inline.** When a term is resolved, write it to the glossary right then — do not batch. Create the file lazily (only when the first term is resolved), using `../templates/glossary-tmpl.md`:
   - base: `docs/architecture/glossary.md`
   - active spec: `docs/specs/{id}/architecture/glossary.md` with `promote: docs/architecture/glossary.md` + `promote_mode: append` front-matter.
   - The glossary is a **glossary and nothing else** — pure domain terms and definitions, totally free of implementation details. It is not a spec, scratch pad, or decision log.

6. Stop when every consequential branch is resolved or explicitly deferred. Do not pad with low-impact preferences.

7. Summarize the resolved decisions and the rationale. **Offer an ADR sparingly** — only when all three are true:
   1. **Hard to reverse** — changing your mind later has meaningful cost.
   2. **Surprising without context** — a future reader will wonder "why this way?"
   3. **The result of a real trade-off** — there were genuine alternatives and one was chosen for specific reasons.

   If any criterion is missing, skip the ADR and fold the outcome back into the design doc / `plan.md` instead. When an ADR is warranted, write it to `docs/architecture/adr/adr-NNNN-<slug>.md` (or `docs/specs/{id}/architecture/` for an active spec, with `promote:` front-matter when it should become canonical).

## Rules

- One question per turn. Never batch. Wait for feedback before the next question.
- Every question carries a recommended answer.
- Explore the codebase before asking anything the code can answer.
- Resolve dependencies in order; do not jump ahead to a decision that hinges on an open one.
- Update the glossary as terms resolve — inline, never batched. Keep it free of implementation detail.
- Offer ADRs only when all three criteria hold; otherwise fold the decision into the plan/design doc.
- Beyond glossary entries written inline, this task does not write the ADR/plan automatically — it produces shared understanding, then proposes where to record it.
