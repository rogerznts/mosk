# Implementation Plan: núcleo determinístico do pipeline

**Branch**: `feature/013-deterministic-pipeline-state` | **Date**: 2026-08-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `docs/specs/013-feature-deterministic-pipeline-state/spec.md`

## Summary

Substituir a escrita permissiva de `current_phase` por um contrato único de
resolução, validação e transição. A implementação mantém `spec-meta.yaml` como
projeção atual, acrescenta histórico append-only, schemas versionados e uma CLI
shell-legível. Tasks, diagnóstico e conclusão passam a consumir a mesma fonte.

A spec 012 já entregou a base fail-closed para gate, waiver, promoções,
resolução ativa/arquivada e `doctor`. Esta spec estende esses contratos; não os
reimplementa.

## Technical Context

**Language/Version**: Bash compatível com Bash 3.2 e zsh no sourcing; Markdown,
YAML simples e JSON Schema declarativo
**Primary Dependencies**: ferramentas POSIX já usadas pelo toolkit (`awk`,
`sed`, `find`, `date`, `mv`, `mkdir`); Git apenas quando disponível
**Storage**: `spec-meta.yaml`, `gate.yaml` e `phase-history.yaml` por spec
**Testing**: self-tests Bash com fixtures temporárias, `bash -n`, ShellCheck em
severidade error, `doctor.sh` e smoke test numa materialização de `mosk/`
**Target Platform**: macOS e Linux, instalações Claude Code e Codex
**Project Type**: toolkit Markdown/YAML/Bash distribuído por template
**Performance Goals**: resolução e transição em tempo linear no número de specs;
nenhuma varredura fora de `docs/specs/`
**Constraints**: zero PyYAML/npm/pip; escrita atômica; idempotência; compatibilidade
de leitura com specs arquivadas no schema anterior; autoridade humana preservada
**Scale/Scope**: seis fases, sete arestas permitidas, 50 tasks auditadas e dois
espelhos (`mosk/.claude/` como produto, `.claude/` como ambiente local)

## Technical Approach

### 1. Contrato canônico de estado

- Declarar fases e arestas em `common.sh`, numa única função consultada por
  validação e transição.
- Criar `transition_spec_phase <spec_dir> <destino> <command>`; manter
  `update_spec_phase` somente como compatibilidade temporária que delega ao novo
  contrato ou falha com orientação clara.
- Tratar `origem == destino` como sucesso idempotente, sem novo evento.
- Bloquear qualquer saída de `archived` e qualquer salto fora da matriz.

### 2. Escrita atômica e histórico

- Adquirir lock por `mkdir` dentro da spec e liberar por `trap`.
- Validar tudo antes da primeira escrita.
- Produzir metadata e histórico em temporários no mesmo filesystem, promover
  por `mv` e restaurar a projeção anterior se a segunda promoção falhar.
- Usar `phase-history.yaml` versionado, com valores controlados pelo toolkit:
  `at`, `from`, `to` e `command`.
- Validar que o último evento concorda com `current_phase`; specs antigas sem
  histórico são aceitas até a primeira transição nova.

### 3. Resolução única

- Criar `resolve_spec_dir <repo_root> <locator> [active|any]` para aceitar número,
  `spec_id` ou branch.
- Confirmar identidade pelo conteúdo de `spec-meta.yaml`, não somente pelo nome
  do diretório.
- Falhar em ausência, duplicidade, metadata ausente/divergente ou modo inválido.
- Migrar `check-prerequisites.sh`, `check-ship-ready.sh` e helpers antigos para
  a interface nova, mantendo aliases estritos quando necessários.

### 4. Schemas e validadores

- Adicionar schemas declarativos versionados em
  `mosk/.claude/mosk/schemas/spec-meta.schema.json` e
  `mosk/.claude/mosk/schemas/qa-gate.schema.json`.
- Manter validadores runtime autocontidos para o subconjunto YAML efetivamente
  consumido pelo shell; os schemas documentam campos, enums e compatibilidade.
- Introduzir schema vigente para gates novos com referência de evidência
  obrigatória em `PASS` e `WAIVED`; aceitar schema 1 apenas como histórico.
- Fazer QA, archive e ship-ready chamarem o mesmo validador.

### 5. CLI e adoção pelas tasks

- Criar `transition-spec-phase.sh` com `--spec`, `--to`, `--command`, `--json` e
  `--help`, usando exit codes 0/1/2.
- Trocar as atualizações diretas em `plan.md`, `tasks.md`, `implement.md`,
  `apply-qa-fixes.md`, `qa-gate.md` e `archive.md` pela CLI.
- Não escolher a próxima fase: cada task informa explicitamente o destino que o
  humano solicitou.

### 6. Diagnóstico e compatibilidade

- Criar `selftest-pipeline-state.sh` para matriz, idempotência, locks,
  atomicidade, resolução, schemas e compatibilidade.
- Ampliar `selftest-toolkit.sh` apenas onde ship-ready e gate se integram ao
  contrato novo.
- Incluir schemas, CLI e histórico no `doctor.sh` e na documentação distribuída.
- Espelhar cada arquivo de produto modificado em `.claude/` e verificar paridade.

## Assumptions and Constraints

- O histórico registra transições bem-sucedidas; tentativas recusadas aparecem
  na saída do comando, não como evento de estado.
- `command` é um enum controlado (`plan`, `tasks`, `implement`,
  `apply-qa-fixes`, `qa-gate`, `archive`, `migration`), evitando serializar
  entrada arbitrária no YAML.
- O archive físico continua sendo responsabilidade de `archive.md`; a transição
  para `archived` só ocorre depois das validações e imediatamente antes do move.
- Schemas antigos são somente leitura. Uma spec ativa passa ao schema vigente na
  primeira transição controlada.
- O contrato não cria fase `clarify`, `security` ou `e2e`; continuam passos
  opcionais dentro da fase corrente.

## Dependencies

- Contratos fail-closed e self-tests entregues pela spec 012.
- Convenção branch/pasta e `spec-meta.yaml` do ADR-0017.
- Política de decisão humana do ADR-0016.
- `docs/discovery/toolkit-autonomy-assessment-roadmap.md`, Etapa 2.

## Project Structure

### Documentation (this feature)

```text
docs/specs/013-feature-deterministic-pipeline-state/
├── spec.md
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pipeline-state.md
└── tasks.md
```

### Product source and local mirror

```text
mosk/.claude/mosk/
├── schemas/
│   ├── spec-meta.schema.json
│   └── qa-gate.schema.json
├── scripts/
│   ├── common.sh
│   ├── transition-spec-phase.sh
│   ├── check-prerequisites.sh
│   ├── check-ship-ready.sh
│   ├── doctor.sh
│   ├── selftest-pipeline-state.sh
│   └── selftest-toolkit.sh
├── tasks/
│   ├── plan.md
│   ├── tasks.md
│   ├── implement.md
│   ├── apply-qa-fixes.md
│   ├── qa-gate.md
│   └── archive.md
└── templates/
    ├── spec-meta-tmpl.yaml
    └── qa-gate-tmpl.yaml

.claude/                         # espelho local dos arquivos acima
README.md
TASKS.md
docs/index.md
```

**Structure Decision**: manter a lógica compartilhada em `common.sh`, expor uma
CLI fina para tasks e reservar `schemas/` a contratos declarativos. Não criar
runtime, pacote ou dependência adicional.

## Implementation Milestones

1. Fechar schemas, entidades e matriz de transições com fixtures de contrato.
2. Implementar resolvedor canônico e validadores de metadata/gate.
3. Implementar transição atômica, histórico, lock e CLI.
4. Migrar as seis tasks de fase e os dois guardrails para a interface única.
5. Integrar doctor, espelhos e documentação.
6. Rodar matriz completa, smoke distribuível e validação de compatibilidade.

## Validation Strategy

- Teste de contrato de cada aresta permitida e de todos os saltos restantes.
- Snapshots/hash antes e depois de falhas injetadas para provar ausência de
  mutação parcial.
- Duas transições concorrentes para provar exclusão mútua e estado final único.
- Fixtures por número, `spec_id`, branch, ativa, arquivada, ausente, duplicada e
  metadata divergente.
- Gate schema 1 histórico, schema vigente válido, waiver incompleto, evidência
  ausente e versão futura.
- Fluxo E2E `specify -> plan -> tasks -> implement -> qa-gate -> implement ->
  qa-gate -> archived` usando uma fixture temporária.
- `bash -n`, ShellCheck error, todos os `selftest-*.sh`, `doctor.sh --json`,
  `audit-docs-paths.sh`, sync dry-run, paridade produto/espelho e `git diff --check`.

## Complexity Tracking

Nenhuma violação estrutural: a solução adiciona uma CLI fina, dois schemas e um
self-test focado, todos dentro da arquitetura Bash/YAML existente.
