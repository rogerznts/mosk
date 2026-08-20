# Helper Scripts (`mosk/.claude/mosk/scripts/`)

Seis scripts. A lista é curta por decisão, não por acaso.

Desde o **ADR-0021**, regra do pipeline vive em `mosk/.claude/mosk/pipeline.yaml`
e é lida pelo **agente**, que tem um parser de verdade. Shell cobre apenas o que
o agente genuinamente não alcança.

## A regra de decisão (ADR-0021 §4)

Antes de escrever qualquer script novo neste repositório, três perguntas, nesta
ordem. A primeira que responder "sim" define a camada:

| # | Pergunta | Camada |
|---|---|---|
| 1 | O fato precisa ser lido por mais de um consumidor, ou sobreviver à sessão? | **YAML** declarativo |
| 2 | É julgamento sobre conteúdo — redigir, avaliar, decidir caso a caso? | **Prompt** (task ou agente) |
| 3 | A aplicação exige algo da lista fechada abaixo? | **Script** |

**Lista fechada — o que o agente não alcança.** Três itens, e ampliá-la exige
um ADR:

1. **corrida com outro processo no remoto** — reserva de número de spec;
2. **geração determinística de derivados em massa** — wrappers de skill,
   symlinks do Codex, reinstalação com remoção de órfãos;
3. **execução obrigatória fora da sessão do agente** — hook, CI, branch
   protection.

Se a regra não cai em nenhum dos três, **não é script**. A ausência de
alternativa declarativa precisa ser demonstrada, não presumida.

**Corolário que já custou caro:** script não lê dado estruturado. Quem lê o YAML
é o agente, que passa o valor resolvido por argumento. A exceção é o
`validate.sh` (caso 3, roda em hook/CI e não tem a quem pedir), e ela é estreita
por construção — ver abaixo.

## Inventário

Todos: `set -e`, `--help|-h`, e `common.sh` via `source` quando precisam.

### `validate.sh`

**O verificador único.** Funde `doctor.sh`, `check-prerequisites.sh`,
`check-ship-ready.sh` e `audit-docs-paths.sh`.

```bash
bash .claude/mosk/scripts/validate.sh ship-ready      # spec fechada e mergeável
bash .claude/mosk/scripts/validate.sh prerequisites --for <fase> [--spec <loc>]
bash .claude/mosk/scripts/validate.sh install         # integridade do toolkit
bash .claude/mosk/scripts/validate.sh docs-paths      # R1..R5 de paths canônicos
bash .claude/mosk/scripts/validate.sh single-source   # redação normativa não copiada
bash .claude/mosk/scripts/validate.sh self-check      # constantes x pipeline.yaml
bash .claude/mosk/scripts/validate.sh fixtures        # 14 fixtures de contrato
bash .claude/mosk/scripts/validate.sh all
```

Exit 0 válido · 1 violações · 2 erro de uso. Sem PyYAML, npm ou pip.

**Como ele lê dados, e por que a exceção é segura.** Apenas campos escalares de
domínio fechado (`CAMPOS_LIDOS`), casados por padrão ancorado com **allowlist**
de caracteres, fail-closed, e **nunca prosa**. `gate: {x}` não vira nada —
simplesmente não é `PASS`. É a decisão 1 do ADR-0020, que aquele ADR mediu e
considerou permanentemente correta; o que se abandonou foi tentar reconhecer
toda forma exótica do YAML.

**Quem o invoca** (ADR-0021 §5 — verificação sem chamador não conta):
`.claude/hooks/guard-spec-merge.sh` intercepta `gh pr merge`, `gh pr create` e
`git merge`. Ele distingue **invocação de menção**: descarta heredoc, quebra por
separador e olha só o primeiro token de cada segmento. As duas versões
anteriores casavam substring e bloquearam o próprio trabalho que as descrevia.

### `create-new-feature.sh`

Cria a spec: reserva o número atomicamente em `refs/spec-numbers/<NNN>` no
`origin`, cria branch e pasta, emite `spec-meta.yaml`, commita e faz push, com
renumeração e retry em colisão.

```bash
bash .claude/mosk/scripts/create-new-feature.sh \
  [--json] [--type feature|fix|hotfix|gmud|refactor|experimental|extension] \
  [--short-name <nome>] [--number N] [--extends <spec-id>] [--no-push] <descrição>
```

**Duas armadilhas de numeração já corrigidas (spec 010) — não reintroduza:**
o prefixo dos branches locais é lido **ancorado no início** do nome
(`^([a-z][a-z-]*/)?([0-9]{3})-`); sem a âncora, `fix/issue-123-foo` vira spec.
E `--number` é normalizado com `$((10#$n))` no parse **e** em
`rebuild_branch_name`; sem isso, `--number 010` é constante octal e reserva 008.

**Branch e pasta são strings diferentes (ADR-0017):**
`{tipo}/{NNN}-{nome}` contra `docs/specs/{NNN}-{tipo}-{nome}`. A ponte é o campo
`branch` do `spec-meta.yaml`, **nunca igualdade de string**.

**A emissão do `spec-meta.yaml` fica aqui, não no agente.** Ela vive dentro do
laço de retry da corrida; tirá-la quebraria a atomicidade branch+pasta+commit+push
que é a razão de o script existir. O emissor canônico é `write_spec_meta` em
`common.sh` — havia uma segunda cópia neste script, e as duas já divergiam.

### `sync.sh`

Materializa derivados. Funde `sync-agents-skills.sh` e `link-codex-skills.sh`.

```bash
bash .claude/mosk/scripts/sync.sh skills     # agentes -> wrappers de skill
bash .claude/mosk/scripts/sync.sh codex      # symlinks .codex/ + AGENTS.md
bash .claude/mosk/scripts/sync.sh all [--clean] [--dry-run] [--force]
```

**Uma direção só (ADR-0015):** o agente em `.claude/agents/mosk-<n>.md` é a
fonte; a skill é o wrapper gerado. `skills-to-agents` foi removido e falha com
mensagem — depois da inversão ele sobrescreveria a definição completa com um
ponteiro de três linhas.

**A `description` é declarada pelo agente**, na primeira linha:
`<!-- skill-description: <Área>: <ações em pt-BR, com gatilhos>. -->`. Nunca
edite a description de um wrapper; edite o agente. Wrappers existentes são
editados **no lugar**: só a linha `description:` é reescrita, e front-matter
extra e corpo escrito à mão sobrevivem.

### `reset-install.sh`

Reinstala o toolkit do zero num projeto consumidor, apagando órfãos que
`degit --force` deixaria para sempre.

```bash
bash <tmp>/.claude/mosk/scripts/reset-install.sh --from <tmp> --to <raiz> [--dry-run] [--json]
```

**Rode sempre a cópia recém-baixada**, nunca a instalada — o script apaga o
diretório onde ele mesmo mora. Nunca toca `.claude/rules/`, `settings.json`,
`docs/`, `CLAUDE.md`, `AGENTS.md` nem `.codex/`.

### `sync-hallmark.sh`

Re-sincroniza o vendor do Hallmark por diff/replay contra o ref pinado em
`VENDOR.md`. Qualquer conflito **aborta sem tocar no vendor**.

```bash
bash .claude/mosk/scripts/sync-hallmark.sh [--ref <sha|tag|branch>] [--dry-run]
```

Nunca copie o upstream por cima do diretório na mão: isso apaga a integração MOSK.

### `common.sh`

Biblioteca compartilhada, nunca executada direto. **18 funções** (eram 39).

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

**Resolução do próprio diretório** cobre bash **e** zsh (`${BASH_SOURCE[0]}` e
`${(%):-%x}`), porque as tasks mandam o agente sourceá-lo no shell dele e o
padrão do macOS é zsh. Antes, `dirname ""` virava `.` e todo caminho resolvia a
partir do cwd, em silêncio (spec 009).

Provê: raiz do repo e branch atual; `resolve_spec_dir` por número, `spec_id` ou
branch; `read_spec_meta` / `write_spec_meta`; `validate_promotion_target` e a
contenção de diretório de spec; `resolve_max_attempts` e `append_run_log` para o
runner.

**Por que a contenção fica em shell:** `validate_promotion_target` e
`validate_spec_dir_containment` precisam resolver symlink contra o sistema de
arquivos. Um agente lê o caminho declarado, mas não pode afirmar para onde um
symlink aponta sem consultar o disco. É verificação de sistema, não de dado.

## O que saiu, e para onde

| era | virou |
|---|---|
| `transition-spec-phase.sh` | `pipeline.yaml` + `data/phase-transition-contract.md` |
| `doctor` · `check-prerequisites` · `check-ship-ready` · `audit-docs-paths` | `validate.sh` |
| `classify-change.sh` | `data/adaptive-work-contract.md` (aplicado pelo agente) |
| `update-agent-context.sh` | instrução dentro de `tasks/plan.md` |
| `migrate-docs-structure` · `migrate-ctx-skills-to-rules` | task `migrate-install.md` |
| `audit-legacy-surface.sh` | `validate.sh single-source` |
| `build-execution-plan` · `run-state` · `run-worktree` | agente + primitiva do runtime |
| os 4 `selftest-*.sh` | fixtures de contrato dentro do `validate.sh` |
| `setup-plan.sh` | `validate.sh prerequisites` |

7.912 → 2.730 linhas; 25 → 6 scripts.

## Convenções

- **Idempotente por padrão.** Rerodar não corrompe estado. Destrutivo expõe `--dry-run`.
- **Help é obrigatório.** Todo script suporta `--help|-h`.
- **Base 10 explícita.** `$((10#$num))` ao ler número com zero à esquerda.
- **Sem destruição silenciosa.** Ao remover ou pular, registre o motivo.
- **Fixture de contrato, não self-test de shell.** O que se prova é que o dado
  declarado e o prompt que o lê concordam.

## Quando rodar o quê

| Ação | Comando |
|---|---|
| Começar uma spec | `create-new-feature.sh` (via `specify`) |
| Confirmar mudança de fase | `data/phase-transition-contract.md` (o agente aplica) |
| Ver se a spec pode mergear | `validate.sh ship-ready` |
| Auditar a instalação | `validate.sh all` |
| Adicionou/removeu agente | `sync.sh all --clean` |
| Atualizar o toolkit num consumidor | `reset-install.sh` (via `/mosk-update`) |
| Migrar instalação legada | task `migrate-install` |
| Atualizar/conferir o Hallmark | `sync-hallmark.sh --dry-run` primeiro |
