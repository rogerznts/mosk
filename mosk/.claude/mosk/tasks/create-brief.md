docOutputLocation: docs/discovery/brief.md
template: `.claude/mosk/templates/project-brief-tmpl.yaml`

---

# create-brief

Produza um brief que delimite problema, usuários, critérios de sucesso e MVP.

## Processo

1. Leia o template e execute `.claude/mosk/tasks/create-doc.md` com o pedido e o
   contexto disponível.
2. Em pedido claro, gere diretamente. Se uma lacuna mudar o enquadramento,
   concentre todas as perguntas bloqueantes em uma única rodada agrupada.
3. Salve em `docs/discovery/brief.md`, preservando blocos `<!-- custom -->`.

Elicitação avançada e `custom_elicitation` são opt-in: use somente quando o
usuário pedir exploração adicional.

## Depois

- Sugira `/mosk-pm` quando o brief estiver pronto para virar PRD.
- Se faltarem evidências de mercado, sugira a pesquisa específica pertinente.
- Se ligado a uma spec ativa, escreva em `docs/specs/{id}/discovery/` com
  `promote: copy` para `docs/discovery/brief.md`.

Não invente problema, público ou métrica que dependam do usuário. Registre
assumptions não bloqueantes e mantenha o rascunho inicial enxuto.
