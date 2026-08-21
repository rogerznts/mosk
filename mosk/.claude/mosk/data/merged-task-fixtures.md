# Fixtures de capacidades fundidas

Estas fixtures provam que uma capacidade pública continua roteável depois que
o arquivo legado desaparece. O bloco entre marcadores é lido por
`validate.sh single-source`; mantenha seis campos TSV por linha.

<!-- merged-task-fixtures:start -->
legacy_task	capability	entrypoints	destinations	expected_result	evidence
map-project.md	project-mapping	.claude/skills/mosk-boot/SKILL.md|.claude/agents/mosk-architect.md	.claude/mosk/tasks/boot.md|.claude/agents/mosk-architect.md	Mapeamento técnico focado ou amplo produz regras compactas e um retrato factual da arquitetura.	covered
review-story.md	post-implementation-story-review	.claude/agents/mosk-qa.md	.claude/mosk/tasks/qa-gate.md|.claude/agents/mosk-qa.md	Revisão pós-implementação verifica critérios no código e registra gate com evidência.	covered
webdesign-output.md	complete-ui-delivery	.claude/agents/mosk-ui-expert.md	.claude/mosk/tasks/hallmark.md|.claude/agents/mosk-ui-expert.md	Entrega visual inclui todos os artefatos pedidos sem placeholders nem truncamento silencioso.	covered
<!-- merged-task-fixtures:end -->

## Cenários executáveis

### Mapeamento de projeto

- Dado um projeto existente e um foco informado, `/mosk-boot` inspeciona stack,
  estrutura, comandos, padrões e riscos relevantes, então grava regras compactas.
- Dado um pedido de retrato técnico aprofundado, `/mosk-architect` produz um
  documento factual do estado atual, com paths verificados, dívida e integrações.
- Nenhuma das rotas exige varrer áreas sem relação com o pedido.

### Revisão pós-implementação de story

- Dada uma story específica, `/mosk-qa qa-gate <story>` seleciona o modo story.
- O QA lê story, diff, testes e evidências; verifica cada AC no resultado entregue.
- O resultado usa o mesmo contrato de achados e score do gate da spec, gravando o
  gate de story sob `qa.qaLocation/gates/`.

### Entrega visual completa

- Dado um pedido por arquivos completos, `/mosk-ui-expert` conta os entregáveis e
  devolve cada um sem placeholders de omissão.
- No fluxo Hallmark, a mesma regra vale sem alterar menus visuais, navegação ou
  escolhas de macroestrutura legítimas.
- Se o limite de resposta for atingido, a saída pausa em fronteira limpa e informa
  exatamente o próximo artefato; nunca afirma que um item incompleto foi entregue.
