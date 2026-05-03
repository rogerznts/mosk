## <!-- Inspired by BMAD and SpecKit -->

docOutputLocation: docs/discovery/market-research.md
template: '.claude/mosk/templates/market-research-tmpl.yaml'

---

# Create Market Research Task

Produce a structured market research report covering market sizing, segments, trends, and strategic implications — written by `mosk-analyst` and stored at `docs/discovery/market-research.md`.

## When to run

- Project needs a defensible market view before committing to scope or positioning.
- Brief is in place but assumptions about market size, segments, or trends are untested.
- A pivot or expansion decision needs framing with sensitivity scenarios.

## Process

1. Load the YAML template at `.claude/mosk/templates/market-research-tmpl.yaml`.
2. Apply the execution rules described in `.claude/mosk/tasks/create-doc.md`:
   - Process each section sequentially.
   - When a section has `elicit: true`, present the 1-9 options block and wait for user input.
   - Use the template's `custom_elicitation` actions for sizing, segmentation, and stress-testing assumptions.
3. Save the populated document to `docs/discovery/market-research.md` (overwrite; preserve `<!-- custom -->` blocks).

## After saving

- Cross-link relevant findings into `docs/discovery/brief.md` if it exists.
- If competitive dynamics surfaced as decisive, suggest `/mosk-analyst competitor analysis` next.
- If bound to an active spec, write inside `docs/specs/{id}/discovery/` with `promote: copy` to `docs/discovery/market-research.md`.

## Guardrails

- Cite sources or mark assumptions explicitly — do not present invented figures as data.
- Sizing math (TAM/SAM/SOM) should show the calculation, not just the number.
- Defer customer-segment deep dives to the elicitation cycle; the initial draft stays at the strategic layer.
