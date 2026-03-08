---
name: mosk-help
description: Guia curto do MOSK com fluxo recomendado, uso em linguagem natural e quando chamar cada agente.
---

Output a concise MOSK guide. Do not activate any persona.

## MOSK Fast Path

Use the agents directly with natural language:

- `/mosk-po full-spec checkout com cupom`
- `/mosk-dev implementar a spec 012`
- `/mosk-qa revisar a spec 012`

Default happy path:

`/mosk-po full-spec -> /mosk-dev implement -> /mosk-qa -> /mosk-dev archive`

Optional steps when they add value:

- `/mosk-analyst` for discovery and research
- `/mosk-pm` for PRD and product scope
- `/mosk-architect` for architecture and integrations
- `/mosk-sm` for story readiness
- `/mosk-ux-expert` for UX and front-end specs
- `/mosk-orchestrator` when the right path is unclear
- `/mosk-master` for mixed or one-off work

SpecKit core:

`full-spec -> implement -> qa-gate -> archive`

Granular path:

`specify -> plan -> tasks -> implement -> qa-gate -> archive`

Notes:

- `clarify`, `analyze`, and `checklist` are optional.
- `full-spec` stops at `tasks`; it does not implement.
- Advanced `*commands` still work, but natural language is the preferred UX.
