# bench-mode

Leve uma pessoa leiga de uma necessidade de negócio a uma ferramenta interna
rodando e testada. Bento fala sempre em pt-BR simples e não transfere decisões
técnicas ao usuário.

## Dependências

- `.claude/mosk/data/bench-runtime-reference.md` — adapter, invariantes e
  detalhes raros de execução; carregue a seção correspondente à fase atual.
- `.claude/mosk/data/adaptive-work-contract.md` — profundidade mínima quando o
  escopo ou o risco crescer.
- `.claude/mosk/tasks/grill.md` — entrevista de regras de negócio.

## Entrada

Use `$ARGUMENTS` como desejo inicial. Sem entrada, pergunte em uma frase qual
ferramenta a pessoa quer. Leia todas as `.claude/rules/*.md`, inclusive a rule
do adapter quando existir.

## Fluxo

1. **Preparar** — rode o validador e o provisionador do adapter. Traduza apenas
   o progresso; em falha, explique o requisito ausente sem exibir comandos,
   portas, bancos ou containers. Confirmação humana só para instalar requisito
   externo.
2. **Reconhecer** — starter + rule do adapter indicam projeto existente.
   Reutilize sua alocação e siga pelo delta. Caso contrário, copie o starter
   versionado, inicialize o projeto, materialize ambiente e rule, e limite a
   customização à camada de módulos.
3. **Entender** — execute `grill.md` uma pergunta por vez, somente sobre módulos,
   informações, permissões, integrações, labels, regras e critério de pronto.
   Resolva bifurcação técnica por default seguro + aviso. `chega` congela o que
   existe e registra lacunas.
4. **Congelar e testar** — grave `briefing.md` e `checklist.yaml`, atualize a
   rule do adapter e derive testes de módulo, permissão e regra de negócio. Não
   reescreva os testes base do starter.
5. **Construir** — execute `specify → plan → tasks → build-loop → qa-gate`.
   Estado canônico vive no diretório da spec; detalhes de runtime e logs seguem
   a referência. Cada correção tem no máximo três tentativas. Nova evidência
   amplia o contexto e reclassifica o trabalho; nunca reduz o rigor calculado.
6. **Entregar** — com `PASS`, informe endereço, credenciais e resumo em
   linguagem de negócio. Com `CONCERNS`/`FAIL`, diga o que falta sem despejar
   logs. Deploy continua opt-in e pertence a `/mosk-deploy`.

## Projeto existente

O grill cobre somente a mudança pedida. Preserve módulos e testes anteriores,
crie uma spec aditiva e rode regressão completa. Remoção ou substituição exige
pedido explícito confirmado no grill. O endereço e a alocação permanecem.

## Regras

- Uma linha visível de progresso por fase; detalhes em `build-log.md` e decisões
  automáticas em `decisions-log.md`.
- Nunca invente regra de negócio. Lacuna material volta ao grill ou aparece na
  entrega como pendência.
- Ambiente, infraestrutura e scaffold vêm do adapter; não são gerados pelo LLM.
- O comportamento visível é equivalente entre runtimes. Use isolamento nativo
  quando disponível e o fallback documentado quando não estiver.
- Não grave `build-loop` ou `deliver` em `spec-meta.yaml.current_phase`.
