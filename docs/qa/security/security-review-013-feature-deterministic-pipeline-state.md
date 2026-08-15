# Security review — spec 013

**SECURITY: PASS** — a segunda rodada revalidou SEC-1 a SEC-4 como resolvidos
em Bash e zsh. Não há finding alto ou médio aberto com confiança superior a
0,8.

## Segunda rodada — revalidação após as correções

### SEC-1 · média · Resolvido — symlink de spec não alcança mais o sink

`validate_spec_storage_root` e `validate_spec_dir_containment` recusam symlink
em `docs`, `docs/specs`, `archive` e no diretório candidato, além de comparar o
pai físico. `transition_spec_phase` repete a contenção imediatamente antes da
validação e das escritas.

- Onde: `mosk/.claude/mosk/scripts/common.sh:410-469` (contenção física),
  `:534-584` (resolvedor) e `:785-840` (sink)
- Evidência: em Bash e zsh, spec symlink, raiz `docs` symlink e `archive`
  symlink foram bloqueados; a chamada direta do sink também falhou e o checksum
  do alvo externo permaneceu inalterado
- Confiança da resolução: 0,99

### SEC-2 · média · Resolvido — gate legado fica restrito ao archive

O schema 1 agora exige simultaneamente `status: archived`,
`current_phase: archived` e pai lexical `archive`. Specs ativas seguem pelo
schema 2 e continuam exigindo evidência.

- Onde: `mosk/.claude/mosk/scripts/common.sh:587-623` (contrato único de gate)
- Evidência: `schema: 1` + `PASS` numa spec ativa foi bloqueado nos dois shells;
  o mesmo gate numa fixture realmente arquivada foi aceito; schema 2 ativo sem
  `evidence_ref` permaneceu bloqueado
- Confiança da resolução: 0,99

### SEC-3 · média · Resolvido — histórico é validado como cadeia completa

O parser estrito exige estrutura e campos únicos por evento. A validação cobre
timestamp UTC, aresta, comando, continuidade, ordem temporal e último destino;
schema 2 posterior a `specify` também exige que o histórico exista.

- Onde: `mosk/.claude/mosk/scripts/common.sh:313-408` (eventos e cadeia) e
  `:525-529` (presença obrigatória)
- Evidência: timestamp/aresta inválidos, cadeia descontínua, tempo regressivo e
  histórico ausente foram bloqueados em Bash e zsh; uma cadeia válida com dois
  eventos foi aceita em ambos
- Confiança da resolução: 0,99

### SEC-4 · média · Resolvido — YAML ambíguo falha antes do consumo

Metadata e gate rejeitam chaves críticas top-level duplicadas antes de ler os
valores. O parser do histórico exige exatamente um `at`, `from`, `to` e
`command` por evento.

- Onde: `mosk/.claude/mosk/scripts/common.sh:249-301` (escalares e duplicatas),
  `:334-369` (campos de evento), `:487-489` (metadata) e `:590-592` (gate)
- Evidência: duplicatas de `gate`, `status` e `from` foram bloqueadas nos dois
  shells; o antigo diferencial `PASS` seguido de `FAIL` não avançou
- Confiança da resolução: 0,98

### Controles adicionais da segunda rodada

- Matriz adversarial independente: 21/21 em Bash e 21/21 em zsh.
- Falha injetada após a primeira promoção restaurou metadata e histórico byte a
  byte nos dois shells.
- Lock pré-adquirido bloqueou a transição sem mutar os arquivos nos dois shells.
- Locator traversal continuou sem chegar a um caminho de filesystem.
- Nenhuma regressão nova explorável com confiança superior a 0,8 foi encontrada.

## Primeira rodada — registro dos findings agora resolvidos

## SEC-1 · MEDIUM · confiança 0,98 — symlink de spec permite escrita fora do workspace

- **Categoria:** path traversal / symlink escape
- **Onde:** `mosk/.claude/mosk/scripts/common.sh:350-357` e
  `mosk/.claude/mosk/scripts/common.sh:585-615`
- **Finding:** `resolve_spec_dir` considera qualquer entrada que satisfaça `-d`,
  inclusive symlink, e devolve o caminho lexical sem validar contenção física sob
  `$REPO_ROOT/docs/specs`. `transition_spec_phase` usa esse resultado como base
  para criar lock, temporários e substituir `spec-meta.yaml` e
  `phase-history.yaml`.
- **Cenário de exploração:** um checkout contém
  `docs/specs/013-...` como symlink para uma spec compatível em outro workspace.
  Ao executar a CLI normal, o resolvedor aceita o link e a transição altera os
  arquivos do destino externo. A reprodução independente resolveu o symlink e
  mudou no alvo externo `current_phase: tasks` para `implement`, acrescentando
  também um evento ao histórico.
- **Recomendação:** rejeitar `docs`, `docs/specs`, `archive` e cada diretório
  candidato quando forem symlinks; comparar os caminhos físicos do candidato e
  da raiz permitida imediatamente antes de qualquer escrita. Fazer
  `transition_spec_phase` validar novamente a contenção do `spec_dir`, para que o
  sink permaneça seguro mesmo quando chamado diretamente.

## SEC-2 · MEDIUM · confiança 0,99 — gate ativo pode se declarar legado e omitir evidência

- **Categoria:** validação de entrada / bypass de controle de negócio
- **Onde:** `mosk/.claude/mosk/scripts/common.sh:387-405` e
  `mosk/.claude/mosk/scripts/common.sh:488-496`
- **Finding:** qualquer `gate.yaml` pode declarar `schema: 1`. O runtime então
  pula todos os campos obrigatórios do schema vigente, inclusive
  `evidence_ref`, sem verificar se a spec é realmente um registro histórico já
  arquivado.
- **Cenário de exploração:** numa spec ativa, um arquivo contendo apenas
  `schema: 1` e `gate: PASS` é aceito por `validate_gate_for_completion`. Com
  tasks marcadas como concluídas, o mesmo gate satisfaz as pré-condições de QA e
  archive, fazendo uma decisão nova se passar por legado e removendo a evidência
  obrigatória do fluxo.
- **Recomendação:** permitir schema 1 somente num caminho de leitura histórica
  explícito e somente para specs já arquivadas. Transições de specs ativas, QA e
  novas decisões devem exigir schema 2; idealmente o chamador informa
  explicitamente `allow_legacy=false|true`, com padrão fail-closed.

## SEC-3 · MEDIUM · confiança 0,97 — histórico forjado passa pela validação de integridade

- **Categoria:** integridade de audit log
- **Onde:** `mosk/.claude/mosk/scripts/common.sh:326-330`
- **Finding:** o validador do histórico confere apenas `schema: 1` e o último
  campo `to`. Ele não valida estrutura dos eventos, timestamps, enums, comando,
  arestas permitidas, continuidade entre `from` e `to` nem ordem cronológica.
- **Cenário de exploração:** um histórico com `at: not-a-date`, origem
  `archived`, destino `implement` e comando `archive` foi aceito quando o último
  `to` coincidia com `current_phase`. Assim, um contribuidor pode truncar ou
  substituir a trilha por eventos impossíveis e ainda obter estado considerado
  íntegro por QA, archive e ship-ready.
- **Recomendação:** validar cada evento do subconjunto YAML suportado: campos
  únicos e obrigatórios, timestamp UTC, enums, correspondência comando/destino,
  aresta permitida, `from` igual ao `to` anterior e timestamps não regressivos.
  O último `to` continua devendo coincidir com a projeção atual.

## SEC-4 · MEDIUM · confiança 0,93 — chaves YAML duplicadas criam veredito ambíguo

- **Categoria:** parser differential / validação de entrada
- **Onde:** `mosk/.claude/mosk/scripts/common.sh:267-282` e
  `mosk/.claude/mosk/scripts/common.sh:383-405`
- **Finding:** `read_yaml_scalar` retorna silenciosamente a primeira ocorrência
  de uma chave top-level e o validador não rejeita duplicatas. Isso permite que
  o runtime shell e consumidores YAML que usam a última ocorrência interpretem
  decisões diferentes.
- **Cenário de exploração:** um gate schema 2 válido com `gate: PASS` seguido de
  `gate: FAIL` foi aceito como PASS por `validate_gate_for_completion`. Um check
  automatizado pode, portanto, liberar a conclusão enquanto outra ferramenta ou
  revisor observa o veredito final como FAIL.
- **Recomendação:** antes de ler valores, exigir exatamente uma ocorrência de
  cada chave crítica top-level (`schema`, `gate`, waiver e evidência) e falhar em
  duplicatas. Aplicar a mesma regra às chaves críticas de metadata e aos campos
  de cada evento do histórico.

## Controles revalidados

- Locator contendo path arbitrário não é concatenado diretamente; a resolução é
  por igualdade de número, `spec_id` ou branch.
- O lock existente bloqueou a segunda tentativa e preservou metadata e histórico
  byte a byte.
- A falha injetada depois da promoção de metadata restaurou metadata e histórico
  nos testes do toolkit.
- Fase desconhecida, salto proibido, schema futuro, gate vigente sem evidência e
  waiver incompleto permanecem fail-closed.
- Não foi encontrado uso de `eval`, interpolação de comando ou entrada YAML em
  sink de execução.

## Escopo e evidências

- Base comparada: `master` no merge-base
  `27091ed8dda1fa9adb8a22f730a1c176a7abb0aa`, incluindo alterações não
  commitadas e arquivos novos da spec 013.
- Superfície revisada em profundidade: `common.sh`,
  `transition-spec-phase.sh`, `check-ship-ready.sh`, schemas de metadata/gate,
  templates, tasks de fase e `selftest-pipeline-state.sh`.
- Primeira rodada: `bash -n`; ShellCheck em severidade error; 34/34 asserções de
  pipeline; `git diff --check`; fixtures adversariais para symlink escape, gate
  schema 1 ativo, histórico inválido, chaves duplicadas, lock e rollback.
- Segunda rodada (`2026-08-15T19:41:55Z`): Bash/zsh syntax; ShellCheck error;
  29/29 asserções comuns; 46/46 de pipeline; 39/39 do toolkit; doctor 7/7 no
  produto, espelho e materialização isolada; matriz adversarial 21/21 por shell;
  quatro pares produto/espelho e `git diff --check`.
- Contagem atual: 0 HIGH, 0 MEDIUM, 0 LOW abertos; SEC-1 a SEC-4 permanecem no
  histórico como resolvidos.

SECURITY: PASS
