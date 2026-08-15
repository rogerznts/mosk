# Implementation Plan: estabilizar contratos do toolkit MOSK

**Branch**: `feature/012-stabilize-toolkit-contracts` | **Date**: 2026-08-15 |
**Spec**: [spec.md](./spec.md)  
**Input**: [roadmap de autonomia](../../discovery/toolkit-autonomy-assessment-roadmap.md)

## Summary

Estabilizar o toolkit antes da expansão de autonomia. A implementação cria um
diagnóstico central autocontido, remove a dependência acidental de PyYAML,
transforma gate válido em pré-condição real de archive/ship-ready, corrige
inconsistências conhecidas e gera o inventário que orientará a remoção ampla dos
workflows herdados do BMAD.

## Technical Context

**Language/Version**: Markdown, YAML simples e Bash compatível com macOS/Linux  
**Primary Dependencies**: Bash, Git, awk, sed, grep, find e utilitários POSIX já
usados pelo MOSK  
**Storage**: arquivos versionados em `docs/`, `.claude/` e `mosk/.claude/`  
**Testing**: self-tests Bash com fixtures temporárias, `bash -n`, dry-runs e
smoke materializado do template  
**Target Platform**: Claude Code e Codex em macOS/Linux  
**Project Type**: template Markdown/YAML/Bash sem aplicação compilada  
**Performance Goals**: diagnóstico completo em poucos segundos no repositório  
**Constraints**: sem PyYAML, npm ou pip; sem alterar o vendor Hallmark; scripts
idempotentes; produto sempre nasce em `mosk/`  
**Scale/Scope**: 12 agentes, 50 tasks, 17 scripts existentes + 2 novos e 30
templates principais

## Scope Summary

Esta spec fecha os defeitos que tornam o estado atual pouco confiável. Ela não
executa a modernização completa das tasks. Em vez disso, entrega uma base que
permite realizar essa reescrita na próxima spec com cobertura automatizada e
inventário completo.

## Technical Approach

### 1. Diagnóstico central

Criar `mosk/.claude/mosk/scripts/doctor.sh` como fachada read-only. O script
executará, em ordem determinística:

1. `bash -n` em todos os scripts do template;
2. `selftest-common.sh` e futuros self-tests reconhecidos;
3. auditoria de referências internas;
4. `audit-docs-paths.sh` sem dependência externa;
5. `sync-agents-skills.sh agents-to-skills --dry-run`, tratando qualquer
   `create` ou `update` como drift;
6. validações de roster e arquivos obrigatórios.

Saída humana curta por default e opção `--json` para automação. Exit codes: 0
íntegro, 1 violação, 2 uso inválido.

### 2. Auditoria YAML sem PyYAML

Substituir a leitura genérica de YAML em `audit-docs-paths.sh` por projeção
limitada ao schema real de `core-config.yaml`: chaves de primeiro e segundo
nível. A solução deve usar awk e fixtures; não tentar implementar YAML completo.

### 3. Contrato mínimo de gate

Adicionar helpers ao `common.sh`:

- localizar a spec correspondente ao branch tanto em `docs/specs/` quanto em
  `docs/specs/archive/` quando a chamada exigir histórico;
- ler o veredito do gate;
- validar `PASS` ou `WAIVED` formalizado;
- emitir causa estável para gate ausente ou bloqueante.

O schema de `WAIVED` ganha `waiver.reason`, `waiver.approved_by` e
`waiver.approved_at`. Como os helpers atuais leem somente escalares de primeiro
nível, a implementação deve escolher uma representação shell-legível e única no
template antes de codificar — preferência por chaves planas
`waiver_reason`/`waiver_approved_by`/`waiver_approved_at`.

`archive.md` chama o validador antes de qualquer promoção ou movimento.
`check-ship-ready.sh` resolve também a pasta arquivada e valida o gate nela.

### 4. Inventário de legado

Criar `docs/specs/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md`
durante a implementação. Cada task terá:

- owner/agente atual;
- rota de ativação;
- tamanho aproximado;
- sinais de legado;
- classificação `manter`, `reescrever`, `fundir` ou `remover`;
- destino ou substituto proposto.

Sinais mínimos: menu obrigatório, elicitação seção por seção, loops 1–9,
instruções duplicadas, exemplos extensos, termos BMAD, referências obsoletas e
ausência de rota.

### 5. Fonte e espelho

Toda mudança de produto será implementada em `mosk/.claude/`. Quando o mesmo
arquivo existir no ambiente local da raiz, sua cópia será atualizada para manter
o MOSK capaz de validar a si próprio. A validação compara as áreas modificadas e
reporta drift não justificado.

## Project Structure

```text
mosk/.claude/mosk/
├── scripts/
│   ├── audit-docs-paths.sh       # remover PyYAML
│   ├── check-ship-ready.sh       # gate + spec arquivada
│   ├── common.sh                 # helpers mínimos de gate/resolução
│   ├── doctor.sh                 # novo diagnóstico central
│   ├── selftest-common.sh
│   └── selftest-toolkit.sh       # novas fixtures de contrato
├── tasks/
│   ├── archive.md
│   ├── artefact.md
│   └── enrich-story.md
└── templates/
    ├── qa-gate-tmpl.yaml
    └── run-log-tmpl.md

docs/specs/012-feature-stabilize-toolkit-contracts/
├── spec.md
├── plan.md
├── tasks.md
├── spec-meta.yaml
└── legacy-task-inventory.md
```

O espelho local equivalente em `.claude/` será atualizado somente para os
arquivos de produto modificados.

## Validation Strategy

### Fixtures obrigatórias

- referência interna válida e quebrada;
- wrapper sincronizado e divergente;
- script Bash válido e inválido;
- gate ausente;
- gate desconhecido;
- `FAIL` e `CONCERNS`;
- `WAIVED` incompleto e completo;
- `PASS`;
- spec ativa e arquivada;
- execução sem módulo Python `yaml`.

### Comandos de validação

```bash
bash mosk/.claude/mosk/scripts/selftest-common.sh --verbose
bash mosk/.claude/mosk/scripts/selftest-toolkit.sh --verbose
bash mosk/.claude/mosk/scripts/doctor.sh
bash mosk/.claude/mosk/scripts/audit-docs-paths.sh --quiet
bash mosk/.claude/mosk/scripts/sync-agents-skills.sh agents-to-skills --dry-run
```

Também executar `bash -n` em todos os scripts e materializar o conteúdo de
`mosk/` num diretório temporário para um smoke sem depender da raiz do repo.

## Risks and Mitigations

- **Parser YAML em shell crescer demais** — limitar a projeção às chaves usadas
  e cobrir com fixtures.
- **Archive bloquear specs antigas legítimas** — aceitar somente `PASS` ou
  `WAIVED` completo; migração excepcional deve ser explícita, não bypass oculto.
- **Doctor virar novo monólito** — manter fachada fina; cada regra complexa vive
  em helper ou self-test próprio.
- **Falso positivo no vendor Hallmark** — excluir o vendor da auditoria genérica
  e manter sua validação no `sync-hallmark.sh`.
- **Drift fonte/espelho** — validar apenas arquivos MOSK modificados e documentar
  exceções locais.

## Milestones

1. Auditorias autocontidas e diagnóstico central.
2. Gate obrigatório em archive e ship-ready.
3. Limpeza dos defeitos conhecidos.
4. Inventário completo do legado.
5. Self-tests, smoke e documentação final.

## Follow-up

A próxima spec, `remove-legacy-bmad-workflows`, consumirá o inventário e fará a
redução estrutural das tasks. Menus, elicitação obrigatória e conteúdo herdado
não serão mantidos apenas por compatibilidade histórica.
