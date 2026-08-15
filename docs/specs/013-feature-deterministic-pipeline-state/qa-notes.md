# QA notes — spec 013

## Quality gate — terceira rodada

**Gate: PASS · score 100** — nenhum achado alto ou médio aberto. A série
`0 → 80 → 100` mostra o fechamento das oito lacunas iniciais e da variante que
reabriu QA-3 na segunda rodada.

QA-3 — "archive precisa bloquear toda promoção obrigatória pendente" — foi
reproduzido independentemente com seis mappings raiz que Ruby/Psych materializa
como `promote`: chave simples, citada, escape Unicode, chave explícita, tag e
tag combinada com Unicode. Cada forma foi exercitada pela transição real para
`archived` em Bash e zsh: 12/12 tentativas retornaram violação de contrato,
metadata e histórico permaneceram byte a byte iguais e nenhum destino `copy`
foi criado.

Os demais achados QA-1 a QA-8 e SEC-1 a SEC-5 foram revalidados pela suíte
completa: identidade canônica, symlinks, schema legado, histórico e migração,
matriz de 36 pares, no-ops, rollback por `HUP`/`INT`/`TERM`, lock, marcadores,
gate/waiver, `score_history`, YAML adversarial, promoções `copy`/`append` e
paridade de mirrors. O relatório independente disponível termina em
[`SECURITY: PASS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md).

### Evidência mecânica da terceira rodada

- Sintaxe Bash/zsh, ShellCheck error e JSON Schemas: PASS.
- Selftests: common 29/29, pipeline 192/192 e toolkit 39/39.
- Doctors: 7/7 no produto, espelho e materialização isolada; pipeline isolado
  192/192.
- Matriz independente de QA-3: 6/6 formas reconhecidas por Psych e 12/12
  decisões Bash/zsh bloqueadas com estado preservado.
- Vinte pares produto/espelho, auditoria documental, sync dry-run e
  `git diff --check`: PASS.
- Nenhuma task mantida escreve `current_phase` diretamente; todas usam a CLI
  canônica.

## Security review — revalidação após `dba01ad`

[`SECURITY: PASS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md).
SEC-1 a SEC-5 permanecem resolvidos. Para QA-3/SEC-4, seis mappings raiz
indentadas que Psych materializa como `promote` — simples, citada, Unicode,
explícita, tag e tag + Unicode — foram bloqueadas pela transição real para
`archived` em Bash e zsh. Metadata e histórico permaneceram byte a byte iguais,
os destinos continuaram ausentes e o gate não foi alterado.

## Quality gate — segunda rodada

**Gate: FAIL · score 80** — 1 achado alto. O score foi calculado pela fórmula
canônica: `100 - (20 × 1) - (10 × 0)`. Série: `0 → 80`.

### QA-3 · alta · Archive ainda aceita promoção obrigatória escondida por YAML alternativo

As correções anteriores fecharam promoções canônicas ausentes ou divergentes,
mas a validação lexical considera top-level apenas uma linha que começa na
coluna zero. YAML aceita uma mapping raiz inteiramente indentada. Com isso,
front-matter contendo somente `"promo\\u0074e"`, chave explícita `? promote` ou
tag YAML, todos com dois espaços iniciais, foi ignorado pelo runtime e
materializado como `promote` por Ruby/Psych.

O impacto foi confirmado numa spec fixture íntegra em `qa-gate`: o artefato
declarava `copy` para `docs/canonical/missing.md`, o destino não existia e a
transição `qa-gate -> archived` retornou exit 0 em Bash e zsh, persistindo
`status: archived` e `current_phase: archived`.

- Contraria: PhaseContract — "archived exige gate válido, evidência presente,
  tasks completas e promoções satisfeitas" (`data-model.md`, seção
  "PhaseContract")
- Também: FR-006 — "cada destino possui pré-condições verificáveis no disco"
  (`spec.md`, seção "Functional Requirements")
- Também: contrato de schema — "toda chave top-level fora da gramática simples
  falha" (`contracts/pipeline-state.md`, seção "Schema compatibility")
- Onde: `mosk/.claude/mosk/scripts/common.sh:860-943` — a validação canônica
  ignora linhas indentadas e o scanner conclui que não há promoção
- Custo: correção localizada no parser restrito de front-matter e três fixtures
  adversariais permanentes em Bash e zsh

### Evidência mecânica da segunda rodada

- Sintaxe Bash/zsh, ShellCheck error e JSON Schemas: PASS.
- Selftests: common 29/29, pipeline 177/177 e toolkit 39/39.
- Doctors: 7/7 no produto, espelho e materialização isolada; pipeline isolado
  177/177.
- Matriz completa, no-ops, sinais `HUP`/`INT`/`TERM`, rollback, locks,
  migração legítima/forjada, YAML adversarial canônico, symlinks, gate legado,
  score history e promoções materiais passaram na suíte oficial.
- Vinte pares produto/espelho, auditoria documental, sync dry-run e
  `git diff --check`: PASS.
- O relatório de segurança disponível começou a rodada como `SECURITY: PASS`,
  mas a combinação independente de indentação + chave alternativa reabre a
  superfície de SEC-4 e o impacto de QA-3; o gate prevalece como `FAIL`.

- Security review final após `c711548`:
  [`SECURITY: PASS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md).
  SEC-1 a SEC-5 foram revalidados como resolvidos em Bash e zsh. A matriz
  independente cobriu migração legítima/forjada, inconsistência de
  `history_origin_schema`, chaves YAML citadas, Unicode, explícitas e com tag em
  metadata, gate e promoção, além de symlink, gate legado e equivalência
  material. Nenhum finding alto ou médio permanece aberto; o gate não foi
  alterado.
- Security review da quarta rodada após `f592dc8`:
  [`SECURITY: CONCERNS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md).
  SEC-1, SEC-2 e SEC-5 estão resolvidos. SEC-3 permanece aberto porque qualquer
  schema 2 pode declarar unilateralmente `origin: migration` e truncar a cadeia;
  SEC-4 permanece aberto porque chaves YAML com escape, como
  `"ga\u0074e"`, ainda divergem entre o runtime shell e parsers completos.
  Ambos os bypasses foram reproduzidos em Bash e zsh; o gate não foi alterado.
- Security review da terceira rodada: [`SECURITY: CONCERNS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md).
  SEC-3 foi reaberto porque histórico schema 2 ainda pode ser truncado; SEC-4
  foi reaberto porque chaves YAML citadas escapam da detecção de duplicidade; e
  SEC-5 mostra que a existência do alvo não prova uma promoção `copy`/`append`.
  Os três findings médios foram reproduzidos em Bash e zsh; o gate não foi
  alterado.
- Security review do diff contra `master`: [`SECURITY: PASS`](../../qa/security/security-review-013-feature-deterministic-pipeline-state.md)
  na segunda rodada, agora preservada apenas como registro histórico.
- Na segunda rodada, SEC-1 (symlink escape no diretório da spec), SEC-2 (schema
  legado numa spec ativa), SEC-3 (histórico malformado) e SEC-4 (chaves YAML
  duplicadas simples) foram considerados resolvidos; a terceira rodada reabriu
  SEC-3 e SEC-4 com variantes que as fixtures anteriores não cobriam.
- Controles confirmados: lock concorrente e rollback injetado preservam estado;
  saltos, schema futuro, gate vigente sem evidência e waiver incompleto bloqueiam.
- A revisão não alterou `current_phase`; a spec permanece em `implement`.

## Correções aplicadas pelo desenvolvimento

### Segunda rodada do quality gate

- QA-3/SEC-4: o validador agora rejeita front-matter cujo primeiro conteúdo
  real começa indentado. Isso fecha mappings raiz que Psych interpreta como
  top-level, mas que o scanner shell antes ignorava.
- Regressões independentes cobrem `"promo\u0074e"`, chave explícita
  `? promote` e tag `!!str promote`, todas com raiz indentada, em Bash e zsh.
  Cada tentativa de archive falha, preserva metadata/histórico byte a byte e
  mantém o destino de promoção ausente.
- A transição canônica `qa-gate -> implement` foi registrada por
  `apply-qa-fixes`; o gate permaneceu intocado.
- Evidência do dev: common 29/29, pipeline 192/192, toolkit 39/39 e doctors 7/7
  no produto, espelho e materialização isolada. Bash/zsh, ShellCheck error,
  schemas, auditoria, sync dry-run, paridade e diff-check passaram.

### Quarta rodada de segurança

- SEC-3: `origin: migration` em metadata schema 2 agora exige
  `history_origin_schema: 1`. O campo é persistido automaticamente somente
  quando a transição converte schema 1; specs novas não o recebem. Trocar apenas
  a origem de um histórico truncado falha em Bash e zsh.
- SEC-4: metadata, gate e front-matter agora passam por validação lexical de
  todas as chaves top-level antes da semântica. Formas citadas, escapes Unicode
  como `"ga\u0074e"`, tags e chaves explícitas ficam fora da gramática canônica
  e falham nos dois shells.
- Evidência do dev: common 29/29, pipeline 177/177 e toolkit 39/39, com fixtures
  independentes para migração legítima, migração unilateral e escapes Unicode
  em metadata, gate e promoção. Doctors 7/7 no produto, espelho e materialização
  isolada; Bash/zsh, ShellCheck error, schemas, auditoria, sync dry-run, paridade
  e diff-check passaram. O gate permaneceu intocado.

### Terceira rodada de segurança

- SEC-3: `phase-history.yaml` agora declara `origin: specify|migration`; specs
  novas precisam começar em `specify -> plan`, enquanto migrações legadas são
  marcadas explicitamente. Histórico schema 2 truncado falha em Bash e zsh.
- SEC-4: metadata, gate e front-matter de promoção rejeitam chaves críticas
  citadas/indentadas e duplicadas antes da leitura shell, eliminando a
  divergência entre primeiro e último valor de parsers YAML.
- SEC-5: `copy`/`append` exigem alvo regular e prova material. `copy` usa
  igualdade byte a byte; `append` exige o corpo sem front-matter como sufixo
  exato. Diretórios, alvos ausentes e conteúdos divergentes bloqueiam archive.
- Evidência do dev: common 29/29, pipeline 167/167 e toolkit 39/39; doctors 7/7
  no produto, espelho e materialização isolada; Bash/zsh, ShellCheck error,
  schemas, auditoria, sync dry-run, paridade e diff-check passaram. O gate
  permaneceu intocado.

- SEC-1: resolvedor e sink agora rejeitam raiz/archive/spec symlink e exigem
  filho físico imediato da área permitida.
- SEC-2: gate schema 1 só é legível numa spec com estado arquivado e localizada
  fisicamente em `docs/specs/archive/`; spec ativa exige schema 2.
- SEC-3: cada evento do histórico valida estrutura, timestamp, aresta, comando,
  continuidade e ordem; schema 2 após `specify` não aceita histórico ausente.
- SEC-4: chaves críticas duplicadas em metadata e gate são bloqueadas; o parser
  estrito do histórico também exige uma ocorrência de cada campo.
- Evidência do dev: 29 asserções comuns, 46 de pipeline e 39 do toolkit; doctor
  7/7 no produto e no espelho; Bash/zsh syntax, ShellCheck error, auditoria,
  sync dry-run, quatro pares de espelho e `git diff --check` passaram.
- Revalidação independente: matriz adversarial 21/21 em Bash e 21/21 em zsh;
  nenhuma regressão nova explorável com confiança superior a 0,8.
- Parecer atualizado pelo `/mosk-security` para `SECURITY: PASS`; a spec continua
  em `implement`.

## Quality gate — primeira rodada

**Gate: FAIL · score 0** — 8 achados: 3 altos e 5 médios. O score foi calculado
pela fórmula canônica: `100 - (20 × 3) - (10 × 5)`, limitado a zero.

### QA-1 · alta · Uma branch diferente pode resolver e alterar a spec errada

O resolvedor aceitou branches não registradas apenas por compartilharem o
número `013`. Também aceitou `spec_number: "999"` e combinações divergentes de
`type`/`branch` dentro da pasta 013, tanto em Bash quanto em zsh.

- Contraria: FR-011 — "o resolvedor aceita número, `spec_id` ou branch e valida
  a correspondência com `spec-meta.yaml`" (`spec.md:152`)
- Também: SC-004 — "metadata divergente retorna falha" (`spec.md:221`)
- Código observado: `mosk/.claude/mosk/scripts/common.sh:505-515,541-570`

### QA-2 · alta · Um sinal entre as gravações deixa estado parcial

Uma fixture injetou `TERM` imediatamente após a promoção de `spec-meta.yaml`.
A operação retornou erro e removeu o lock, porém a metadata ficou na nova fase
enquanto o histórico continuou na anterior; a validação posterior falhou por
divergência.

- Contraria: FR-008 — "metadata e histórico são protegidos contra escrita
  parcial" (`spec.md:146`)
- Também: SC-002 — "em 100% das falhas simuladas, ambos permanecem byte a byte
  iguais" (`spec.md:217`)
- Código observado: `mosk/.claude/mosk/scripts/common.sh:798,840-857`

### QA-3 · alta · Archive aceita promoção obrigatória ainda pendente

Numa fixture em `qa-gate` com gate `PASS`, um artefato declarou
`promote: docs/canonical/not-created.md` e `promote_mode: copy`. A transição para
`archived` retornou sucesso mesmo com o alvo ausente; o estado final foi gravado
sem a promoção.

- Contraria: PhaseContract — "archived exige gate válido, evidência presente,
  tasks completas e promoções satisfeitas" (`data-model.md:45`)
- Também: FR-006 — "cada destino possui pré-condições verificáveis no disco"
  (`spec.md:141`)
- Código observado: `mosk/.claude/mosk/scripts/common.sh:750-780`

### QA-4 · média · Instantes de metadata e histórico podem divergir

Uma fixture alterou `last_phase_change` para `2099-01-01T00:00:00Z`, mantendo o
último evento do histórico em `2026-08-15T19:04:33Z`. A metadata foi aceita em
Bash e zsh.

- Contraria: cenário US3.1 — "metadata e histórico concordam sobre origem,
  destino, instante e comando responsável" (`spec.md:102`)
- Código observado: `mosk/.claude/mosk/scripts/common.sh:502-529,375-405`

### QA-5 · média · Esclarecimentos em plan.md não impedem tasks

Depois de `specify -> plan`, uma fixture adicionou
`[NEEDS CLARIFICATION: decisão pendente]` a `plan.md`. A transição
`plan -> tasks` avançou em Bash e zsh.

- Contraria: edge case — "artefato obrigatório contendo marcador bloqueante
  impede a transição" (`spec.md:118`)
- Código observado: `mosk/.claude/mosk/scripts/common.sh:756-779`

### QA-6 · média · Gate vigente passa sem histórico de scores

Um gate schema 2 sem `score_history` foi aceito em Bash e zsh. O JSON Schema
também não declara esse campo em `properties` ou `required`, embora a task e o
template o tratem como obrigatório.

- Contraria: FR-013 — "gate e waiver possuem schemas versionados com campos
  obrigatórios" (`spec.md:156`)
- Também: GateDecision — "a decisão inclui score e histórico de scores"
  (`spec.md:183`)
- Código observado: `mosk/.claude/mosk/schemas/qa-gate.schema.json:6-25` e
  `mosk/.claude/mosk/scripts/common.sh:610-623`

### QA-7 · média · A matriz proibida não está toda no self-test

O harness cobre as seis arestas permitidas, mas apenas três das 24 combinações
proibidas e um único no-op. Uma matriz independente confirmou que o `case`
atual decide corretamente as 36 combinações em Bash e zsh; o gap é de cobertura
permanente, não da tabela atual.

- Contraria: SC-001 — "100% das transições permitidas e proibidas possuem
  fixture" (`spec.md:215`)
- Também: FR-020 — "self-tests cobrem a matriz completa" (`spec.md:170`)
- Harness observado: `mosk/.claude/mosk/scripts/selftest-pipeline-state.sh:133-191`

### QA-8 · média · Um par produto/espelho permanece divergente

Dezoito pares modificados estão idênticos. O par
`mosk/.claude/mosk/templates/project-rule-tmpl.md` ↔
`.claude/mosk/templates/project-rule-tmpl.md` diverge: o espelho local omite
três linhas sobre symlinks, histórico, YAML duplicado e gates legados.

- Contraria: FR-019 — "produto sob `mosk/` e espelho local sob `.claude/`
  permanecem equivalentes" (`spec.md:168`)
- Também: T020 — "espelhar todos os arquivos modificados e provar ausência de
  drift" (`tasks.md:57`)

### Evidência mecânica da rodada

- `bash -n` e `zsh -n`: todos os scripts do produto passaram.
- ShellCheck em severidade error: passou.
- Selftests: common 29/29, pipeline 46/46 e toolkit 39/39.
- Doctor: 7/7 no produto, espelho e materialização isolada de `mosk/`.
- Segurança: `SECURITY: PASS`; matriz adversarial 21/21 por shell.
- Schemas JSON válidos por `jq`; auditoria documental, sync dry-run e
  `git diff --check` passaram.
- O gate foi verificado em contexto limpo por um subagente `mosk-qa`; os
  findings altos também foram reproduzidos diretamente pela revisão principal.

## Correções do desenvolvimento — rodada 1 do gate

- QA-1: o locator agora é classificado antes da busca. Número usa apenas o
  prefixo numérico; `spec_id` exige a pasta exata; branch canônica deriva a
  pasta esperada e precisa concordar exatamente com a metadata. Schema 2 cruza
  número, tipo e slug entre todos os campos.
- QA-2: o trap de transição restaura os backups se qualquer saída não-zero
  ocorrer depois do início da promoção de metadata. Fixtures externas injetam
  `HUP`, `INT` e `TERM` após o primeiro `mv` em Bash e zsh e comprovam estado
  byte a byte idêntico e ainda válido.
- QA-3: `validate_spec_promotions_satisfied` virou o contrato compartilhado do
  sink de `archived` e do `check-ship-ready.sh`. `copy`/`append` pendentes e
  destinos inválidos bloqueiam; `manual` continua informativo.
- QA-4: `validate_phase_history` compara o `at` final também com
  `last_phase_change`.
- QA-5: `spec.md`, `plan.md` e `tasks.md` são verificados conforme a fase e
  qualquer marcador `[NEEDS CLARIFICATION` bloqueia sem mutação.
- QA-6: gate schema 2 exige uma ocorrência de `score_history`, valores 0–100 e
  último item igual a `quality_score`; o JSON Schema e as fixtures foram
  alinhados. O template de metadata também voltou a declarar
  `last_phase_change` como obrigatório.
- QA-7: o harness percorre os 36 pares da matriz, as seis arestas permitidas,
  as 24 proibidas, os seis no-ops e a preservação do estado. A suíte passou de
  46 para 142 asserções.
- QA-8: os 20 pares produto/espelho modificados foram comparados byte a byte e
  ficaram idênticos, incluindo `project-rule-tmpl.md`.

### Validação do desenvolvimento

- Sintaxe: todos os scripts passaram em Bash e zsh.
- ShellCheck em severidade error: passou.
- Selftests: common 29/29, pipeline 142/142 e toolkit 39/39.
- Doctor: 7/7 no produto, ambiente local e materialização isolada de `mosk/`.
- JSON Schemas: válidos por `jq`.
- Auditoria documental, sync agente → skill em dry-run, 20 pares de espelho e
  `git diff --check`: passaram.
- O `gate.yaml` permanece `FAIL` com score 0; somente QA pode reavaliar o
  veredito. A spec voltou para `implement` por `apply-qa-fixes`.
