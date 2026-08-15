# Inventário de modernização das tasks

**Escopo:** as 50 tasks em `mosk/.claude/mosk/tasks/` na abertura da spec 012.

**Objetivo:** alimentar a futura spec `remove-legacy-bmad-workflows`.

## Critério

- `manter`: fluxo atual, direto e com função distinta; aceita ajustes locais.
- `reescrever`: função válida, mas prompt prolixo, interativo, duplicado ou
  excessivamente herdado.
- `fundir`: função útil, porém melhor absorvida por outra task ou agente.
- `remover`: sem rota ou sem problema atual que justifique existir.

BMAD e SpecKit são linhagem, não contrato de compatibilidade. Menus obrigatórios,
loops de elicitação, exemplos gigantes e instruções duplicadas não são mantidos
por tradição.

## Inventário completo

| Task | Owner/rota atual | Sinal observado | Decisão | Destino proposto |
|---|---|---|---|---|
| `advanced-elicitation.md` | suporte indireto de documentos | loop 0–9 e reoferta obrigatória | reescrever | ação opt-in curta, nunca happy path |
| `analyze.md` | `mosk-po analyze` | fluxo curto e objetivo | manter | preservar como revisão opcional |
| `apply-qa-fixes.md` | `mosk-dev` / `mosk-qa` | 169 linhas e blocos BMAD | reescrever | correção por finding estável e evidência |
| `archive.md` | `mosk-dev archive` | função única e necessária | manter | preservar com gate determinístico |
| `artefact.md` | `mosk-po artefact` | fluxo moderno de adendo | manter | corrigir referências e preservar |
| `assess-nfr.md` | `mosk-qa` | 352 linhas, exemplos e schema repetido | reescrever | avaliação adaptativa usando contrato do gate |
| `assess-risk.md` | `mosk-qa` | 365 linhas e relatório prescritivo extenso | reescrever | matriz compacta orientada ao diff |
| `assess-security.md` | `mosk-security audit` | workflow curto | manter | preservar auditoria de codebase |
| `audit-docs-paths.md` | `mosk-dev` | wrapper simples para script | manter | usar via `doctor.sh` |
| `bench-mode.md` | `mosk-bench` | 321 linhas e seam legado de runtime | reescrever | manter comportamento, reduzir contrato e duplicação |
| `boot.md` | `mosk-boot` | longo, mas cobre migração e regras críticas | manter | modularizar apenas com teste equivalente |
| `checklist.md` | `mosk-po checklist` | suporte opcional curto | manter | preservar como opt-in |
| `clarify.md` | `mosk-po clarify` | pergunta agrupada e limite claro | manter | preservar como opt-in |
| `correct-course.md` | `mosk-sm` | escolha de modo e cerimônia herdada | reescrever | diagnóstico direto com uma decisão agrupada |
| `create-brief.md` | `mosk-analyst` | wrapper curto sobre criação de documento | manter | apontar para novo criador direto |
| `create-competitor-analysis.md` | `mosk-analyst` | wrapper curto | manter | preservar com template enxuto |
| `create-deep-research-prompt.md` | `mosk-analyst` | 280 linhas e opções obrigatórias | reescrever | prompt de pesquisa gerado em uma passagem |
| `create-doc.md` | Analyst/PM/Architect/UX | desabilita eficiência; elicitação 1–9 obrigatória | reescrever | criação direta; elicitação somente opt-in |
| `create-epic.md` | `mosk-po` | 162 linhas e estrutura herdada | reescrever | épico compacto ligado a PRD/spec |
| `create-market-research.md` | `mosk-analyst` | wrapper curto | manter | preservar com template enxuto |
| `create-story.md` | `mosk-po` | 313 linhas, muitas perguntas e exemplos | reescrever | story mínima com AC verificável |
| `deploy-mode.md` | `mosk-deploy` | adapter Payload/Railway escopado | manter | preservar como fluxo especializado |
| `design-tests.md` | `mosk-qa` | 176 linhas de framework BMAD | reescrever | seleção de testes guiada por risco real |
| `draft-frontend-prompt.md` | `mosk-ux-expert` | saída única e curta | manter | preservar |
| `enrich-story.md` | `mosk-sm` | execução sequencial antiga e refs sem extensão | reescrever | readiness compacto baseado no delta |
| `execute-checklist.md` | vários agentes | seleção de menu e metodologia repetitiva | reescrever | executor não interativo por checklist explícito |
| `facilitate-brainstorming-session.md` | `mosk-analyst` | menus e workshop longo por default | reescrever | técnica adaptativa escolhida automaticamente |
| `full-spec.md` | `mosk-po full-spec` | composição curta do happy path | manter | preservar |
| `grill.md` | Analyst/Architect/Bench | entrevista objetiva e escopada | manter | preservar, com teto por risco |
| `hallmark.md` | `mosk-ui-expert` | integração vendorizada explícita | manter | preservar contrato do vendor |
| `implement.md` | `mosk-dev implement` | fluxo atual e limites claros | manter | evoluir depois com execution plan estruturado |
| `index-docs.md` | `mosk-dev index-docs` | longo, porém fonte funcional do índice | manter | mover mecânica para script em spec futura |
| `map-project.md` | sem rota atual | 345 linhas e sobreposição com boot/architect | fundir | absorver descoberta técnica em `boot` e Architect |
| `orq-run.md` | `mosk-orq` | moderno, mas dependente de prosa/runtime | manter | reestruturar na spec do runner, não remover |
| `plan.md` | `mosk-po plan` | fluxo curto | manter | preservar e adicionar evidência estruturada depois |
| `planner.md` | `mosk-pm planner` | 301 linhas e múltiplas responsabilidades | reescrever | separar leitura mecânica de síntese de produto |
| `qa-gate.md` | `mosk-qa qa-gate` | contrato atual de independência e score | manter | fortalecer schema e automação |
| `review-story-draft.md` | PO/SM | workflow sequencial antigo | reescrever | readiness único com findings acionáveis |
| `review-story.md` | `mosk-qa` | 325 linhas e sobreposição com gate | fundir | incorporar como modo story-level do `qa-gate` |
| `security-review.md` | `mosk-security review` | diff-aware e falsos positivos explícitos | manter | preservar |
| `shard-doc.md` | PM/Architect | 197 linhas e dependência/fallback extensos | reescrever | script mecânico com confirmação mínima |
| `specify.md` | `mosk-po specify` | fluxo curto e defaults agressivos | manter | preservar |
| `tasks.md` | `mosk-po tasks` | fluxo curto | manter | evoluir para gerar execution plan depois |
| `trace-spec.md` | `mosk-qa` | 273 linhas e relatório BMAD extenso | reescrever | matriz derivada e compacta por AC |
| `webdesign-brutalist.md` | `mosk-ui-expert` | estilo especializado | manter | preservar como referência de execução |
| `webdesign-minimalist.md` | `mosk-ui-expert` | estilo especializado | manter | preservar |
| `webdesign-output.md` | `mosk-ui-expert` | guardrails duplicáveis no agente | fundir | absorver em UI Expert/Hallmark |
| `webdesign-redesign.md` | `mosk-ui-expert` | auditoria visual especializada | manter | preservar |
| `webdesign-soft.md` | `mosk-ui-expert` | estilo especializado | manter | preservar |
| `webdesign-stitch.md` | `mosk-ui-expert` | geração de design system | manter | preservar |

## Contagem

- manter: 29
- reescrever: 18
- fundir: 3
- remover: 0
- total: 50

Nenhuma task foi marcada para remoção imediata sem antes absorver sua capacidade.
`map-project.md`, `review-story.md` e `webdesign-output.md` deixam de existir
somente depois que os destinos propostos cobrirem seus usos reais.

## Ordem sugerida para a próxima spec

1. Reescrever `create-doc.md` e `advanced-elicitation.md`.
2. Consolidar readiness: `enrich-story.md` + `review-story-draft.md`.
3. Enxugar QA: risk, NFR, trace e review story sobre um contrato comum.
4. Absorver as três tasks classificadas como `fundir`.
5. Reduzir Bench e Planner sem alterar seus resultados públicos.
