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

Passo a passo (quando quiser controlar cada fase):

`specify -> plan -> tasks -> implement -> qa-gate -> archive`

Passos opcionais, quando agregam:

- `/mosk-analyst` for discovery and research
- `/mosk-pm` for PRD and product scope
- `/mosk-architect` for architecture and integrations
- `/mosk-ux-expert` for UX and front-end specs
- `/mosk-ui-expert` for visual polish and design system
- `/mosk-sm` for story readiness
- `/mosk-security` for a review of the pending changes before the gate

Notes:

- `clarify`, `analyze`, and `checklist` are optional.
- `full-spec` stops at `tasks`; it does not implement.
- Advanced `*commands` still work, but natural language is the preferred UX.
- Em dúvida sobre o próximo passo? `/mosk-suggestion` lê a fase atual da
  spec e sugere o próximo agente com um prompt pronto para colar.

## Como o agente trabalha

- **Documento sai pronto.** Brief, PRD, arquitetura, spec: o agente escreve o
  documento inteiro de uma vez. Não há menu numerado nem aprovação seção a
  seção.
- **Pergunta só quando muda o resultado.** Se a dúvida altera escopo,
  arquitetura, dados ou efeito externo, o agente junta tudo e faz **uma única
  rodada** de perguntas. O resto ele resolve com default seguro e informa junto
  com a entrega.
- **Aprofundar é opt-in.** Peça — "critica isso", "explora alternativas",
  "questiona essa seção" — e o agente aprofunda o trecho indicado e devolve o
  documento. Nenhum template liga isso sozinho.
- **O rigor acompanha o risco da mudança.** `implement`, `qa-gate`,
  `security-review` e a corrida autônoma medem a mesma coisa: o alcance da
  mudança, o quanto ela é reversível, se toca superfície sensível e quanta
  evidência existe. Um ajuste isolado recebe leitura curta e teste focado;
  mudança em dados, segurança, contrato público ou produção recebe mais
  contexto, verificação independente e revisão de segurança antes do gate. O
  agente diz em uma linha como dimensionou o trabalho — e pode subir esse nível
  no meio do caminho, nunca baixar. Se quiser mais profundidade, peça.
- **Isso muda o esforço, não quem decide.** Mudança de fase, veredito de gate e
  desvio de rota continuam sendo do usuário.

## Tasks com nomes parecidos — qual quando?

- `create-story` (`/mosk-po`): **emite** a story formal a partir do épico/PRD. Primeiro passo.
- `enrich-story` (`/mosk-sm`): **enriquece** a story existente com contexto técnico (Dev Notes, citações de arquitetura) antes do dev pegar. Era chamada `draft-story`.
- `review-story-draft` (`/mosk-sm` ou `/mosk-po`): valida a story **antes** do dev — "a spec está completa e implementável?"
- `qa-gate <story>` (`/mosk-qa`): revisa a story **depois** do dev — "o código atende à spec, aos padrões e aos ACs?" Gera o gate de story.
