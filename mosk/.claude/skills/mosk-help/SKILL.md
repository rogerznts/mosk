---
name: mosk-help
description: Guia curto do MOSK com fluxo recomendado, uso em linguagem natural e quando chamar cada agente.
---

Output a concise MOSK guide. Do not activate any persona. Write the guide
in the project's communication language (field *Idioma de comunicação* in
`.claude/rules/project.md`); default to **português (pt-BR)** when none is
set. Keep skill names, commands and paths in their literal form.

## MOSK Fast Path

Use the agents directly with natural language:

- `/mosk-po full-spec checkout com cupom`
- `/mosk-dev implementar a spec 012`
- `/mosk-qa revisar a spec 012`

Fluxo padrão:

`/mosk-po full-spec -> /mosk-dev implement -> /mosk-qa -> /mosk-dev archive`

Passos opcionais, quando agregam:

- `/mosk-analyst` for discovery and research
- `/mosk-pm` for PRD and product scope
- `/mosk-architect` for architecture and integrations
- `/mosk-sm` for story readiness
- `/mosk-ux-expert` for UX and front-end specs
Núcleo do pipeline:

`full-spec -> implement -> qa-gate -> archive`

Passo a passo (quando quiser controlar cada fase):

`specify -> plan -> tasks -> implement -> qa-gate -> archive`

Notes:

- `clarify`, `analyze`, and `checklist` are optional.
- `full-spec` stops at `tasks`; it does not implement.
- Advanced `*commands` still work, but natural language is the preferred UX.
- Em dúvida sobre o próximo passo? `/mosk-suggestion` lê a fase atual da
  spec e sugere o próximo agente com um prompt pronto para colar.

## Tasks com nomes parecidos — qual quando?

- `create-story` (`/mosk-po`): **emite** a story formal a partir do épico/PRD. Primeiro passo.
- `enrich-story` (`/mosk-sm`): **enriquece** a story existente com contexto técnico (Dev Notes, citações de arquitetura) antes do dev pegar. Era chamada `draft-story`.
- `review-story-draft` (`/mosk-sm` ou `/mosk-po`): valida a story **antes** do dev — "a spec está completa e implementável?"
- `qa-gate <story>` (`/mosk-qa`): revisa a story **depois** do dev — "o código atende à spec, aos padrões e aos ACs?" Gera o gate de story.
