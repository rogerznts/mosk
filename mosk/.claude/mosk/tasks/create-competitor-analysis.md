## <!-- Inspired by BMAD and SpecKit -->

docOutputLocation: docs/discovery/competitor-analysis.md
template: '.claude/mosk/templates/competitor-analysis-tmpl.yaml'

---

# Create Competitor Analysis Task

Produce a competitive analysis report covering direct and indirect competitors, their positioning, strengths/weaknesses, and the resulting differentiation opportunities — written by `mosk-analyst` and stored at `docs/discovery/competitor-analysis.md`.

## When to run

- Project needs an explicit competitive frame before nailing positioning or feature scope.
- A direct competitor surfaced and needs a structured assessment (not a tactical reaction).
- Differentiation claims in the brief or PRD need stress-testing.

## Process

1. Load the YAML template at `.claude/mosk/templates/competitor-analysis-tmpl.yaml`.
2. Apply the execution rules described in `.claude/mosk/tasks/create-doc.md`:
   - Process each section sequentially.
   - When a section has `elicit: true`, present the 1-9 options block and wait for user input.
   - Use the template's `custom_elicitation` actions for war-gaming, partnership-vs-competition, and disruption analysis.
3. Save the populated document to `docs/discovery/competitor-analysis.md` (overwrite; preserve `<!-- custom -->` blocks).

## After saving

- Surface differentiation opportunities into `docs/discovery/brief.md` and `docs/prd/` if those exist.
- If the analysis exposed a defensibility gap, suggest `/mosk-architect` to evaluate technical moats.
- If bound to an active spec, write inside `docs/specs/{id}/discovery/` with `promote: copy` to `docs/discovery/competitor-analysis.md`.

## Guardrails

- Distinguish observed facts (pricing, public features) from inferred strategy.
- Avoid one-sided narratives: each competitor section must include both threats they pose and gaps they leave.
- Keep the diff vs. our project explicit — vague "we are better at UX" claims must be replaced with concrete deltas.
