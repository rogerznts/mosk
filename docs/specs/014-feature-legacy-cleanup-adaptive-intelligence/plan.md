# Implementation Plan: Limpeza do legado e inteligência adaptativa

**Branch**: `feature/014-legacy-cleanup-adaptive-intelligence` | **Date**: 2026-08-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/spec.md`

## Summary

Reduzir a superfície operacional do MOSK sem perda de capacidade: substituir cerimônia BMAD por um happy path direto, reconciliar as 50 tasks existentes em um inventário executável, absorver as três fusões já identificadas e consolidar contratos duplicados. Em paralelo, introduzir um classificador portátil de mudança que converte sinais observáveis em quatro perfis (`compact`, `standard`, `elevated`, `critical`) e governa contexto, especialistas e validação.

A estratégia preserva integralmente os contratos determinísticos das specs 012 e 013. A fonte continua em `mosk/.claude/`; `.claude/` é espelho local. A política adaptativa terá duas camadas: julgamento semântico do agente para declarar sinais controlados e um script determinístico para aplicar pisos, pontuação e produzir o perfil. Isso evita tanto heurística opaca quanto um fluxo máximo para toda mudança.

## Technical Context

**Language/Version**: Bash 3.2+, zsh compatível, Markdown, YAML simples e JSON Schema
**Primary Dependencies**: utilitários POSIX já exigidos pelo toolkit; Ruby/Psych apenas nos testes de parsing existentes; nenhuma dependência nova em runtime
**Storage**: arquivos versionados em `mosk/.claude/`, espelhos em `.claude/` e artefatos de spec em `docs/specs/`
**Testing**: selftests Bash/zsh, testes de contrato por fixtures, `doctor.sh`, ShellCheck, auditoria de referências, sync/diff-check e instalação isolada
**Target Platform**: macOS e Linux com Bash/zsh suportados pelo toolkit
**Project Type**: toolkit de agentes baseado em arquivos e scripts shell
**Performance Goals**: classificação local sem rede em menos de 1 segundo; happy path sem round-trip de menu; carregar apenas os grupos de contexto do perfil selecionado
**Constraints**: preservar mudanças locais, não alterar a máquina de estados da spec 013, não adicionar parser YAML de runtime, manter operações de path fail-closed e parar antes da automação por worktrees da Etapa 4
**Scale/Scope**: 50 tasks, agentes/skills consumidores, templates de documentos, scripts de sincronização e matriz de fixtures compartilhada

## Technical Approach

### 1. Inventário executável e orçamento de remoção

- Usar `docs/specs/archive/012-feature-stabilize-toolkit-contracts/legacy-task-inventory.md` como baseline e reconciliá-la com as 50 tasks atuais.
- Criar uma fonte canônica compacta em `mosk/.claude/mosk/data/task-dispositions.tsv` com task, ação, destino, consumidores e estado da evidência.
- Medir antes das alterações o corpus das 18 tasks de reescrita; registrar a baseline e a fórmula de medição para validar a redução de 30%.
- Impedir conclusão de `merge`/`remove` se houver referência ativa, rota sem destino ou fixture de capacidade sem cobertura.
- Tratar ocorrências históricas/licenças por allowlist estreita; não aplicar substituição textual global em arquivos arquivados ou conceitos legítimos como o menu visual do Hallmark.

### 2. Contrato adaptativo comum

- Criar `mosk/.claude/mosk/data/adaptive-work-contract.md` como fonte humana canônica e `mosk/.claude/mosk/schemas/change-profile.schema.json` como forma de saída verificável.
- Criar `mosk/.claude/mosk/scripts/classify-change.sh`, sem rede nem parser YAML, aceitando apenas enums controlados e emitindo JSON estável.
- Separar duas responsabilidades: o agente identifica sinais com evidência; o script aplica pontuação, pisos de segurança/irreversibilidade e mapeia perfil para orçamento e validação.
- Permitir elevação explícita de rigor, mas nunca rebaixamento abaixo do piso calculado.
- Não persistir um novo estado obrigatório por spec nesta etapa; o perfil é incluído nos artefatos ou relatórios dos fluxos que já existem.

### 3. Happy path direto

- Reescrever `create-doc.md` para produzir o documento diretamente e perguntar apenas quando uma lacuna muda materialmente o resultado.
- Converter `advanced-elicitation.md` em capacidade explicitamente opt-in; remover os menus `1-9` e os hard stops derivados de `elicit: true` dos wrappers e templates padrão.
- Fazer `create-brief`, pesquisa de mercado/concorrentes, PRD e arquitetura compartilharem a mesma política de clarificação agrupada.
- Preservar a pausa humana para decisões irreversíveis, escopo material e dúvidas reais.

### 4. Consolidação em ondas

1. **Documentos e elicitação**: `create-doc`, wrappers e templates.
2. **Readiness de story**: `enrich-story` e `review-story-draft` compartilham contrato sem duplicar checklist.
3. **QA adaptativo**: `assess-risk`, `assess-nfr`, `design-tests`, `trace-spec` e revisões consomem o perfil comum e um contrato de evidência.
4. **Fusões**: absorver `map-project` em boot/Architect, `review-story` no modo story do qa-gate e `webdesign-output` no UI Expert/Hallmark; remover apenas após matriz verde.
5. **Fluxos extensos**: compactar Bench e Planner sem mudar suas capacidades públicas.
6. **Cauda legada**: reescrever as tasks restantes da baseline, integrar órfãs e eliminar referências operacionais antigas.

### 5. Composição e espelhos

- Atualizar agentes e skills para referenciar contratos canônicos, sem copiar tabelas extensas para cada prompt.
- Sincronizar `mosk/.claude/` → `.claude/` somente pelos scripts oficiais.
- Atualizar ajuda e documentação para falar em linguagem natural, perfil adaptativo e limites humanos, sem expor o mecanismo como uma nova cerimônia.

## Adaptive Decision Algorithm

O agente fornece sinais enumerados. O classificador soma o score e aplica pisos; em empate ou ausência de evidência, prevalece o perfil mais conservador.

| Dimensão | Valores | Pontos |
|---|---|---:|
| Escopo | localized / multi_file / cross_domain / public_contract | 0 / 1 / 2 / 3 |
| Reversibilidade | easy / coordinated / irreversible | 0 / 1 / 3 |
| Superfície sensível | none / paths_state / data_security / production_critical | 0 / 2 / 3 / 5 |
| Evidência | strong / partial / absent | 0 / 1 / 2 |
| Ambiguidade | clear / bounded / material | 0 / 1 / 2 |

Mapeamento base: `0–2 compact`, `3–5 standard`, `6–9 elevated`, `10+ critical`.

Pisos:

- `data_security` exige no mínimo `elevated`.
- `production_critical` ou `irreversible` exige `critical`.
- `cross_domain` com evidência `absent` exige no mínimo `elevated`.
- Uma dúvida que altere escopo ou ação irreversível exige pausa humana independentemente do perfil.

O contrato detalhado e os budgets estão em [contracts/adaptive-work-contract.md](./contracts/adaptive-work-contract.md).

## Project Structure

### Documentation (this feature)

```text
docs/specs/014-feature-legacy-cleanup-adaptive-intelligence/
├── spec.md
├── plan.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── adaptive-work-contract.md
├── spec-meta.yaml
├── phase-history.yaml
└── tasks.md
```

### Source Code (repository root)

```text
mosk/.claude/
├── agents/                         # consumidores do contrato comum
├── skills/                         # wrappers públicos sincronizados
└── mosk/
    ├── data/
    │   ├── adaptive-work-contract.md
    │   └── task-dispositions.tsv
    ├── schemas/
    │   └── change-profile.schema.json
    ├── scripts/
    │   ├── classify-change.sh
    │   ├── audit-legacy-surface.sh
    │   └── selftest-adaptive-work.sh
    ├── tasks/                      # corpus de 50 tasks a consolidar
    └── templates/                  # elicit flags e instruções duplicadas

.claude/                            # espelho local gerado, nunca fonte manual
docs/                               # ajuda, índice e evidências de QA/security
```

**Structure Decision**: Manter a arquitetura file-based existente. O contrato humano fica em `data/`, a saída formal em `schemas/` e a decisão determinística em `scripts/`. Não criar serviço, banco ou framework novo.

## Data Model

As entidades e invariantes estão em [data-model.md](./data-model.md). Nenhuma delas adiciona estado concorrente ao pipeline: `TaskDisposition` é catálogo versionado; `ChangeProfile` é saída derivada; `ContextBudget` e `ValidationFloor` são políticas imutáveis.

## Dependencies and Ordering

- **D1**: Baseline do inventário antes de reescrever ou medir redução.
- **D2**: Contrato adaptativo + schema + fixtures antes de migrar agentes e tasks consumidoras.
- **D3**: Contrato de clarificação direta antes de alterar wrappers e templates.
- **D4**: Matriz de capacidade e auditoria de referências antes das três fusões.
- **D5**: Alterações completas na fonte antes de sincronizar espelhos.
- **D6**: Security review antes do qa-gate porque scripts, paths, parsing e gates são superfícies sensíveis.

## Implementation Milestones

### M1 — Baseline e guardrails

Congelar inventário, métrica de linhas, allowlist histórica e testes que falham com menu obrigatório, task órfã, referência quebrada ou classificação divergente.

### M2 — Núcleo adaptativo

Entregar contrato, schema, classificador, fixtures e testes Bash/zsh. Integrar primeiro em `implement`, `security-review`, `qa-gate` e `orq-run` para validar composição sem alterar estado.

### M3 — Happy path

Simplificar criação documental e elicitação, depois migrar wrappers/templates. Demonstrar caso claro sem pergunta, caso ambíguo com uma rodada e opt-in avançado explícito.

### M4 — Consolidação

Executar as seis ondas da seção técnica, concluindo cada remoção somente após rota, cobertura e auditoria verdes.

### M5 — Integração e documentação

Atualizar agentes/skills, sincronizar espelhos, ajuda, inventário final e relatório de redução.

### M6 — Gates

Executar regressão completa, security diff-aware, QA autônomo e ciclos de correção até PASS. O PR é o ponto de parada da etapa.

## Validation Strategy

### Contract tests

- Fixtures de sinais cobrindo limites 2/3, 5/6 e 9/10, todos os pisos e elevação manual.
- Mesma saída JSON em Bash e zsh; schema válido; argumentos desconhecidos falham fechados.
- Matriz de budgets e validações consistente com o perfil.

### Behavior tests

- Fluxos claros sem menu/confirm; ambiguidades agrupadas em uma rodada; advanced elicitation apenas opt-in.
- Cada capacidade de task fundida continua acessível pela rota de destino.
- Tasks sem consumidor e referências a paths removidos fazem o audit falhar.

### Regression and safety

- Selftests common, pipeline-state, toolkit e adaptive-work.
- `doctor.sh` em produto, local e instalação isolada.
- Bash/zsh syntax, ShellCheck error, schemas, mirrors e diff-check.
- Regressões das specs 012/013, inclusive traversal, symlink, YAML adversarial, histórico e gates fail-closed.
- Security review com foco em parsing de argumentos, path containment, comando dinâmico, classificação manipulável e bypass de pisos.

### Completion evidence

- Relatório antes/depois das 18 tasks de reescrita com fórmula reproduzível e redução mínima de 30%.
- Inventário final 50/50, zero órfãs e evidência por fusão/remoção.
- Auditoria BMAD operacional limpa fora da allowlist.
- QA gate PASS e security PASS antes do PR.

## Assumptions and Constraints

- O classificador formaliza a profundidade mínima; não substitui julgamento de produto nem autoriza ações fora do escopo.
- Agentes podem elevar o perfil com justificativa, nunca reduzi-lo abaixo do piso.
- Contagem de tokens não é portátil; budgets usam grupos de fontes e gatilhos de expansão.
- Arquivos históricos/arquivados não entram no corpus operacional nem na limpeza textual.
- A alteração local de archive da spec 013 observada no workspace não integra esta spec e deve permanecer fora de staging/commits da Etapa 3.

## Complexity Tracking

| Decisão | Por que é necessária | Alternativa mais simples rejeitada porque |
|---|---|---|
| Script determinístico + julgamento semântico | Garante concordância entre agentes e mantém sinais ligados a evidência contextual | Apenas prompt seria difícil de testar; apenas heurística shell não entende intenção |
| Schema e contrato humano separados | Um valida forma; o outro explica comportamento e budgets aos agentes | Duplicar regras em cada task recriaria a divergência que a etapa remove |
| Inventário executável versionado | Torna remoções e fusões auditáveis | Documento narrativo sozinho não bloqueia task órfã ou referência quebrada |

## Risks and Mitigations

- **Risco**: limpeza textual remove semântica válida. **Mitigação**: allowlist, classificação por consumidor e matriz de capacidades.
- **Risco**: classificador vira nova burocracia. **Mitigação**: saída compacta, automática e visível apenas quando útil; sem novo estado obrigatório.
- **Risco**: score mascara sinal crítico. **Mitigação**: pisos independentes e fail-closed.
- **Risco**: redução de linhas incentiva minificação ilegível. **Mitigação**: medir apenas corpus operacional e exigir legibilidade, fontes sob demanda e cobertura equivalente.
- **Risco**: espelho local mistura mudanças fora do escopo. **Mitigação**: staging seletivo, sync controlado e diff-check.

## No New Technology Decision

Nenhuma tecnologia ou convenção externa nova é introduzida; `update-agent-context.sh` não é necessário.
