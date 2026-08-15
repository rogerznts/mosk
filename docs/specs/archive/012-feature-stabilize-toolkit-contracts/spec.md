# Feature Specification: estabilizar contratos do toolkit MOSK

**Feature Branch**: `feature/012-stabilize-toolkit-contracts`

**Created**: 2026-08-15

**Status**: Draft

**Input**: avaliação funcional e roadmap em
`docs/discovery/toolkit-autonomy-assessment-roadmap.md`

## Problema

O MOSK possui um pipeline amplo e bem documentado, mas algumas garantias
críticas ainda dependem exclusivamente da interpretação dos agentes. Hoje é
possível arquivar uma spec sem gate aprovado, o verificador de documentação
falha quando PyYAML não está instalado e existem referências e exemplos
obsoletos no template.

Antes de ampliar a autonomia ou reescrever os workflows herdados do BMAD, o
toolkit precisa de uma base autocontida que detecte contratos quebrados e impeça
falsos estados de conclusão.

## User Scenarios & Testing

### User Story 1 — Validar uma instalação com um único comando (Priority: P1)

Como mantenedor do MOSK, quero executar um diagnóstico central e receber um
resultado determinístico sobre a integridade do template, sem instalar pacotes
adicionais.

**Why this priority**: sem um verificador autocontido, regressões em prompts,
referências e scripts só aparecem durante o uso em projetos consumidores.

**Independent Test**: materializar `mosk/` num diretório temporário e executar o
diagnóstico; uma instalação íntegra retorna exit code 0, enquanto fixtures com
referência quebrada, wrapper divergente ou shell inválido retornam exit code 1
com a causa identificada.

**Acceptance Scenarios**:

1. **Given** uma instalação limpa do template, **When** o mantenedor executa o
   diagnóstico, **Then** todas as verificações passam sem dependências externas
   além das já declaradas pelo MOSK.
2. **Given** uma task que aponta para um template inexistente, **When** o
   diagnóstico roda, **Then** ele falha e informa arquivo, linha e referência.
3. **Given** um agente e seu wrapper fora de sincronia, **When** o diagnóstico
   roda, **Then** ele falha e recomenda a sincronização correta.

---

### User Story 2 — Impedir conclusão sem decisão válida de QA (Priority: P1)

Como responsável por uma entrega, quero que archive e ship-ready rejeitem uma
spec sem gate válido, para que `archived` nunca seja confundido com evidência de
qualidade.

**Why this priority**: o estado atual permite um falso positivo de conclusão e
compromete toda autonomia construída sobre o pipeline.

**Independent Test**: criar fixtures de spec com gate ausente, `FAIL`,
`CONCERNS`, `PASS` e `WAIVED`; somente `PASS` e `WAIVED` formalizado podem
prosseguir para archive e ship-ready.

**Acceptance Scenarios**:

1. **Given** uma spec sem `gate.yaml`, **When** archive é solicitado, **Then** o
   fluxo para antes de mover arquivos e explica que o QA ainda não decidiu.
2. **Given** um gate `FAIL` ou `CONCERNS`, **When** archive é solicitado,
   **Then** o fluxo recusa a conclusão sem oferecer bypass genérico.
3. **Given** um gate `WAIVED`, **When** faltam justificativa, aprovador ou data,
   **Then** archive e ship-ready recusam a spec.
4. **Given** um gate `PASS` ou `WAIVED` formalizado e as demais condições
   satisfeitas, **When** a spec é arquivada, **Then** ship-ready encontra e
   valida o artefato mesmo depois de ele ser movido para `docs/specs/archive/`.

---

### User Story 3 — Eliminar defeitos conhecidos e mapear o legado (Priority: P2)

Como mantenedor, quero remover referências quebradas e inconsistências já
confirmadas e produzir um inventário objetivo dos padrões herdados, para que a
próxima spec possa removê-los sistematicamente.

**Why this priority**: corrigir os defeitos conhecidos estabiliza a base; mapear
o legado evita uma reescrita ampla sem critério ou cobertura.

**Independent Test**: o diagnóstico passa no template e um inventário lista
cada task como `manter`, `reescrever`, `fundir` ou `remover`, com evidência e
destino proposto.

**Acceptance Scenarios**:

1. **Given** as referências internas do template, **When** o diagnóstico roda,
   **Then** não há caminho quebrado para agent, skill, task, template, checklist
   ou script.
2. **Given** a documentação do roster, **When** ela é comparada com os arquivos
   em `mosk/.claude/agents/`, **Then** todas as superfícies informam 12 agentes.
3. **Given** as 50 tasks atuais, **When** a auditoria de legado é concluída,
   **Then** cada uma possui classificação, motivo e ação futura proposta.

### Edge Cases

- Branch de spec cujo diretório já foi movido para `docs/specs/archive/`.
- Gate YAML parcialmente escrito ou com valor desconhecido.
- `WAIVED` sem metadados de aprovação.
- Referências com ou sem extensão dentro de backticks.
- Template materializado fora de um repositório Git.
- Sistemas com Bash e utilitários POSIX, mas sem módulos Python adicionais.
- Arquivos do vendor Hallmark, que não devem ser tratados como conteúdo MOSK
  comum nem reescritos pelo diagnóstico.

## Requirements

### Functional Requirements

- **FR-001**: O toolkit DEVE oferecer um comando central de diagnóstico que
  componha as verificações de integridade existentes.
- **FR-002**: O diagnóstico DEVE ser autocontido e não depender de PyYAML, npm,
  pip ou outro pacote não declarado.
- **FR-003**: O diagnóstico DEVE validar sintaxe dos scripts Bash.
- **FR-004**: O diagnóstico DEVE validar referências literais entre agents,
  skills, tasks, templates, checklists e scripts.
- **FR-005**: O diagnóstico DEVE verificar a paridade agente → wrapper sem
  modificar arquivos.
- **FR-006**: O diagnóstico DEVE executar os self-tests existentes e propagar
  corretamente seus exit codes.
- **FR-007**: Toda falha DEVE informar regra, arquivo e causa em linguagem
  acionável.
- **FR-008**: `archive` DEVE exigir gate `PASS` ou `WAIVED` formalizado antes de
  mover a spec.
- **FR-009**: Um gate `WAIVED` DEVE registrar justificativa, aprovador e
  timestamp.
- **FR-010**: `check-ship-ready.sh` DEVE validar o gate mesmo quando a spec já
  estiver em `docs/specs/archive/`.
- **FR-011**: Gate ausente, inválido, `FAIL` ou `CONCERNS` DEVE bloquear archive
  e ship-ready.
- **FR-012**: O template de gate DEVE documentar o schema de waiver.
- **FR-013**: Referências quebradas já identificadas em `artefact.md` e
  `enrich-story.md` DEVEM ser corrigidas.
- **FR-014**: O timestamp inválido do template de run log DEVE ser corrigido.
- **FR-015**: README, CLAUDE, rules e documentação de agentes DEVEM refletir o
  roster real de 12 agentes.
- **FR-016**: A spec DEVE produzir um inventário das 50 tasks com as categorias
  `manter`, `reescrever`, `fundir` ou `remover`.
- **FR-017**: O inventário DEVE marcar menus obrigatórios, elicitação por seção,
  exemplos extensos, duplicações, vocabulário BMAD e tasks sem rota.
- **FR-018**: Alterações de produto DEVEM ser feitas primeiro em `mosk/`; o
  espelho local da raiz deve ser atualizado apenas para manter o ambiente de
  desenvolvimento equivalente.
- **FR-019**: O diagnóstico DEVE ignorar ou tratar explicitamente o vendor
  Hallmark para não sinalizar seu conteúdo upstream como dívida MOSK.
- **FR-020**: Todos os novos scripts DEVEM oferecer `--help`, ser idempotentes e
  retornar exit codes estáveis.

### Assumptions and Defaults

- O comando será implementado em Bash e reutilizará os scripts existentes.
- O nome definitivo do comando será decidido no plan; `doctor` é o default.
- A validação de gate desta spec é um guardrail mínimo. A máquina completa de
  estados pertence à etapa seguinte do roadmap.
- O inventário de legado não executa a remoção ampla nesta spec.
- Compatibilidade com formatos antigos só será mantida quando houver uso real e
  custo baixo; padrões BMAD não têm presunção de permanência.

### Out of Scope

- reescrever todas as tasks herdadas;
- introduzir a máquina completa de estados;
- criar `execution-plan.yaml`;
- reestruturar o `/mosk-orq`;
- alterar o Bench ou o deploy;
- adicionar um novo runtime ou backend de orquestração.

## Success Criteria

### Measurable Outcomes

- **SC-001**: O diagnóstico passa em uma cópia limpa de `mosk/` usando apenas as
  dependências declaradas pelo toolkit.
- **SC-002**: 100% das referências internas cobertas pelo diagnóstico resolvem
  para arquivos existentes.
- **SC-003**: 100% dos scripts Bash do template passam em `bash -n`.
- **SC-004**: Fixtures provam que gate ausente, inválido, `FAIL`, `CONCERNS` e
  `WAIVED` incompleto não podem ser arquivados.
- **SC-005**: Fixtures provam que `PASS` e `WAIVED` completo podem seguir quando
  as demais condições estão satisfeitas.
- **SC-006**: `check-ship-ready.sh` valida uma spec já movida para archive em vez
  de tratá-la como branch sem spec.
- **SC-007**: As 50 tasks aparecem exatamente uma vez no inventário de legado.
- **SC-008**: Todas as superfícies documentais mantidas pelo projeto informam o
  roster correto de 12 agentes.
- **SC-009**: O comando central retorna 0 para instalação íntegra, 1 para
  violação e 2 para erro de uso.
- **SC-010**: O full-spec termina sem marcadores `NEEDS CLARIFICATION`.

## Próxima etapa após esta spec

Abrir `remove-legacy-bmad-workflows` usando o inventário produzido aqui. Essa
spec deverá remover ou reescrever a gordura herdada, não apenas documentá-la.

---

**Arquivado em:** 2026-08-15
**Status final:** Concluído
**Promoções aplicadas:** nenhuma — 0 copy, 0 append, 0 manual
