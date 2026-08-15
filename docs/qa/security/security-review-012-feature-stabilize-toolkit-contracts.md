# Security review — spec 012

**SECURITY: PASS** — segunda rodada concluída sem finding aberto com confiança
superior a 0,8. O finding médio da primeira rodada foi corrigido e revalidado.

### SEC-1 · média · Resolvido — destino de promoção podia escrever fora do repositório

O fluxo lê `promote:` de um artefato versionado e orienta `copy` ou `append`
diretamente para esse valor, sem exigir que ele permaneça sob `docs/`. Um
contribuidor pode declarar, por exemplo, `promote: ../../.zshrc` com
`promote_mode: append`; quando o mantenedor confirma `aplicar tudo`, o archive
manda acrescentar o corpo ao arquivo fora do workspace. O ship-ready não
interrompe esse caso: ele concatena o mesmo valor a `$REPO_ROOT` e considera a
promoção aplicada se o caminho atravessado existir. Isso permite escrita
arbitrária nos arquivos acessíveis ao usuário que executa o agente e pode levar
à execução de código na próxima abertura do shell.

- Onde na primeira rodada: `mosk/.claude/mosk/tasks/archive.md:50` (origem do destino) e
  `mosk/.claude/mosk/tasks/archive.md:66` (operações `copy`/`append` sem
  contenção)
- Também: `mosk/.claude/mosk/scripts/check-ship-ready.sh:107` (destino lido sem
  validação) e `mosk/.claude/mosk/scripts/check-ship-ready.sh:111` (travessia
  aceita na checagem de existência)
- Correção: criar um helper único para validar destinos de promoção antes de
  qualquer leitura ou escrita; rejeitar caminhos absolutos, segmentos `..`,
  modos fora de `copy|append|manual` e qualquer caminho cujo pai canônico ou
  componente symlink escape de `$REPO_ROOT/docs/`. Usar o mesmo helper no
  archive e no ship-ready, sempre em modo fail-closed, e cobrir travessia e
  symlink escape com fixtures.

**Resolução na segunda rodada:** `validate_promotion_target` centraliza a
validação lexical e física em `common.sh`. O helper aceita somente
`copy|append|manual`, exige caminho relativo iniciado por `docs/`, rejeita
segmentos vazios, `.` e `..`, recusa `docs/` e o arquivo final quando são
symlinks e compara fisicamente o pai existente com o `docs/` físico. O
ship-ready transforma qualquer erro do helper em falha bloqueante. O archive
valida ao montar o plano e novamente imediatamente antes da escrita, usando
somente o caminho absoluto devolvido pelo helper.

- Evidência no código: `mosk/.claude/mosk/scripts/common.sh:282` (helper),
  `mosk/.claude/mosk/scripts/check-ship-ready.sh:142` (consumo fail-closed) e
  `mosk/.claude/mosk/tasks/archive.md:52`/`:79` (validação em dois momentos)
- Evidência adversarial: destino canônico e pai novo sob `docs/` foram aceitos;
  path absoluto, traversal, modo desconhecido, destino fora de `docs/`,
  separador duplo, `docs/` como symlink, symlink intermediário para fora e
  symlink no arquivo final foram bloqueados
- Confiança da resolução: 0,97

## Segunda rodada — correções após `5595122`

Além de SEC-1, as correções dos achados de QA foram rastreadas até seus sinks:

- `QA-1` passou a resolver referências relativas somente para checagem de
  existência; não introduziu execução, escrita ou interpolação de comando.
- `QA-2` removeu o fail-open de branches numerados. Spec ausente, ambígua ou
  sem metadata agora bloqueia o ship-ready; branch e caminhos permanecem
  citados e não passam por `eval`.
- `QA-3` normaliza whitespace no subconjunto YAML shell-legível antes de testar
  motivo e aprovador. As chaves consultadas são constantes internas e os
  valores não chegam a um sink de execução.

Nenhuma dessas mudanças introduziu vulnerabilidade explorável com confiança
superior a 0,8.

## Resumo da revisão

- Primeira rodada: commit `5595122` contra `5595122^`
- Segunda rodada: correções não commitadas sobre `5595122`
- Arquivos alterados triados: 33
- Arquivos sensíveis revisados em profundidade: `common.sh`,
  `check-ship-ready.sh`, `audit-docs-paths.sh`, `doctor.sh`,
  `selftest-toolkit.sh`, `archive.md` e `qa-gate-tmpl.yaml`
- Foco: resolução de spec, contenção de paths, parser YAML shell-legível,
  promoção, archive e ship-ready
- Verificações da primeira rodada: ShellCheck; 29 asserções de
  `selftest-common.sh`; 21 asserções de `selftest-toolkit.sh`;
  `doctor.sh --json` com 7/7 checks
- Verificações da segunda rodada: `bash -n`; ShellCheck em severidade error; 29
  asserções de `selftest-common.sh`; 35 asserções de `selftest-toolkit.sh`;
  `doctor.sh --json` validado por `jq`; matriz adversarial independente 10/10;
  cinco pares produto/espelho sem drift; `git diff --check`
- Contagem atual: 0 HIGH, 0 MEDIUM, 0 LOW abertos; SEC-1 permanece no histórico
  como resolvido
- Revisão concluída: sim

SECURITY: PASS
