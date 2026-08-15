# Feature Specification: núcleo determinístico do pipeline

**Feature Branch**: `feature/013-deterministic-pipeline-state`
**Created**: 2026-08-15
**Status**: Draft
**Input**: Implementar a Etapa 2 do roadmap, aproveitando os contratos entregues
pela spec 012 e cobrindo máquina de estados, schemas, pré/pós-condições e
histórico de transições.

## Problema

A spec 012 tornou gate, archive, resolução histórica e diagnóstico fail-closed,
mas a progressão normal ainda depende de tasks editarem `current_phase`
diretamente. O helper atual aceita qualquer valor e qualquer salto, não valida
os artefatos exigidos pela fase e não deixa um histórico estruturado. Assim, o
estado documentado pode divergir do trabalho que existe no disco mesmo quando o
gate final é rigoroso.

Esta etapa transforma o pipeline existente em um núcleo determinístico sem
ampliar a autonomia do runner e sem reescrever ainda os workflows herdados. A
decisão de mudar de fase continua pertencendo ao humano; o toolkit passa a
executar essa decisão por uma única interface validada, atômica e auditável.

## Atores

- Pessoa que conduz a spec e decide quando avançar, corrigir ou arquivar.
- Agentes MOSK que materializam a transição já solicitada pelo usuário.
- QA e CI, que precisam reproduzir o estado e bloquear conclusões inválidas.
- Mantenedor do toolkit, que precisa diagnosticar drift entre metadata,
  artefatos, gate e histórico.

## User Scenarios & Testing

### User Story 1 — Avançar apenas por transições válidas (Priority: P1)

Como pessoa conduzindo uma spec, quero que cada mudança de fase valide a origem,
o destino e os artefatos obrigatórios, para que nenhum comando consiga pular
uma etapa ou declarar um estado que o disco não comprova.

**Why this priority**: é o contrato central da Etapa 2 e a condição para ampliar
autonomia com segurança.

**Independent Test**: uma matriz de fixtures exercita todos os caminhos
permitidos e proibidos e comprova que falhas não alteram metadata nem histórico.

**Acceptance Scenarios**:

1. **Given** uma spec em `specify` com `spec.md` válido, **When** o usuário
   solicita `plan`, **Then** a transição para `plan` ocorre atomicamente e fica
   registrada.
2. **Given** uma spec em `specify`, **When** uma task tenta saltar diretamente
   para `implement`, **Then** a operação falha com causa legível e nenhum byte do
   estado é alterado.
3. **Given** uma spec em `qa-gate` com findings corrigíveis, **When** o usuário
   solicita correções, **Then** o retorno controlado para `implement` é aceito.
4. **Given** uma spec arquivada, **When** qualquer task tenta mudar sua fase,
   **Then** a operação falha e o registro histórico permanece imutável.

---

### User Story 2 — Resolver e validar uma spec por uma fonte única (Priority: P1)

Como agente ou script do pipeline, quero resolver uma spec por número, `spec_id`
ou branch usando a mesma regra, para eliminar interpretações divergentes entre
tasks, `check-prerequisites`, archive e `check-ship-ready`.

**Why this priority**: uma máquina de estados aplicada à spec errada é pior que
uma ausência de validação.

**Independent Test**: fixtures ativas e arquivadas são resolvidas pelos três
identificadores; ausência, ambiguidade, metadata incompatível e branch sem spec
falham de forma fechada.

**Acceptance Scenarios**:

1. **Given** uma spec ativa íntegra, **When** ela é localizada pelo número, nome
   da pasta ou branch registrada, **Then** todas as formas retornam o mesmo
   diretório canônico.
2. **Given** duas candidatas para o mesmo número ou metadata divergente,
   **When** a resolução é solicitada, **Then** nenhuma candidata é escolhida por
   heurística.
3. **Given** uma consulta histórica explícita, **When** a spec já está
   arquivada, **Then** ela pode ser localizada sem reabri-la para tasks normais.

---

### User Story 3 — Auditar estado, gate e evidências (Priority: P2)

Como QA ou mantenedor, quero schemas versionados e um histórico estruturado de
transições, para explicar como a spec chegou ao estado atual e reproduzir a
decisão de conclusão.

**Why this priority**: rastreabilidade torna falhas diagnosticáveis e impede que
metadata aparentemente válida esconda uma sequência inválida.

**Independent Test**: uma spec percorre o fluxo completo, volta uma vez para
correção e é arquivada; o validador reconstrói a sequência, valida gate, waiver,
evidências e promoções e produz o mesmo resultado em nova execução.

**Acceptance Scenarios**:

1. **Given** uma transição bem-sucedida, **When** o estado é consultado,
   **Then** metadata e histórico concordam sobre origem, destino, instante e
   comando responsável.
2. **Given** gate ou waiver fora do schema, **When** QA, archive ou ship-ready o
   valida, **Then** o mesmo erro e exit code são produzidos por todas as
   superfícies.
3. **Given** uma spec histórica no schema anterior, **When** o diagnóstico roda,
   **Then** ela continua legível sem ser reescrita; novas specs usam o schema
   vigente.

### Edge Cases

- Reexecução da mesma task quando a spec já está na fase de destino.
- Interrupção entre a gravação de metadata e do histórico.
- Duas tentativas concorrentes de transição na mesma spec.
- `current_phase`, `status`, branch ou `spec_id` desconhecidos ou em branco.
- Artefato obrigatório ausente, vazio, ilegível ou ainda contendo marcador
  `NEEDS CLARIFICATION` bloqueante.
- Gate `PASS`, `FAIL`, `CONCERNS`, `WAIVED` completo/incompleto e schema futuro
  não reconhecido.
- Histórico ausente em uma spec antiga e histórico truncado numa spec nova.
- Spec ativa e arquivada compartilhando o mesmo número.
- Branch base ou branch numerada sem `spec-meta.yaml` correspondente.
- Promoção com destino inexistente, traversal ou escape por symlink.

## Requirements

### Functional Requirements

- **FR-001**: O toolkit MUST definir o conjunto canônico de fases `specify`,
  `plan`, `tasks`, `implement`, `qa-gate` e `archived`.
- **FR-002**: O toolkit MUST declarar uma matriz única de transições permitidas,
  incluindo o retorno explícito `qa-gate -> implement` para correções.
- **FR-003**: Toda mudança de fase MUST passar por uma única interface; edições
  diretas de `current_phase` nas tasks mantidas MUST ser eliminadas.
- **FR-004**: A interface MUST rejeitar fase desconhecida, salto proibido,
  metadata inválida e qualquer saída de `archived`.
- **FR-005**: Repetir uma transição já concluída MUST ser idempotente: retornar o
  estado atual sem duplicar eventos nem alterar timestamps.
- **FR-006**: Cada destino MUST ter pré-condições verificáveis no disco, no
  mínimo: artefatos das fases anteriores, tasks completas antes de QA e gate
  válido antes de archive.
- **FR-007**: Cada task de fase MUST validar sua pós-condição antes de confirmar
  a transição; falha MUST preservar integralmente o estado anterior.
- **FR-008**: A atualização de metadata e histórico MUST ser protegida contra
  escrita parcial e tentativas concorrentes.
- **FR-009**: Cada transição bem-sucedida MUST acrescentar um evento estruturado
  com versão, timestamp UTC, origem, destino e comando responsável.
- **FR-010**: O estado atual MUST ser derivável de `spec-meta.yaml` e verificável
  contra o último evento do histórico; divergência MUST falhar de forma fechada.
- **FR-011**: O toolkit MUST oferecer um resolvedor canônico que aceite número,
  `spec_id` ou branch e valide a correspondência com `spec-meta.yaml`.
- **FR-012**: O resolvedor MUST distinguir consulta ativa de consulta histórica
  e rejeitar ausência ou ambiguidade sem escolher por heurística.
- **FR-013**: `spec-meta.yaml`, gate e waiver MUST possuir schemas versionados,
  com campos obrigatórios, enums e regras de compatibilidade explícitas.
- **FR-014**: A validação em runtime MUST permanecer autocontida em Bash e
  ferramentas de sistema já exigidas pelo MOSK, sem PyYAML, npm ou pip.
- **FR-015**: Gates novos MUST referenciar evidência verificável; `PASS` e
  `WAIVED` sem evidência exigida pelo schema vigente MUST bloquear conclusão.
- **FR-016**: Schemas históricos suportados MUST continuar legíveis; schema
  desconhecido ou futuro MUST falhar com orientação de atualização.
- **FR-017**: `check-prerequisites`, tasks de fase, archive,
  `check-ship-ready` e doctor MUST consumir o mesmo resolvedor e validadores.
- **FR-018**: A interface de estado MUST oferecer saída humana e `--json`, com
  exit codes estáveis: `0` sucesso, `1` violação de contrato e `2` erro de uso.
- **FR-019**: O produto sob `mosk/` e o espelho local sob `.claude/` MUST
  permanecer equivalentes para toda superfície modificada.
- **FR-020**: Self-tests MUST cobrir a matriz completa de transições, resolução,
  schemas, atomicidade, idempotência, compatibilidade e conclusão.
- **FR-021**: A mudança MUST preservar a autoridade humana: a interface executa
  apenas a transição solicitada por uma task já invocada e não escolhe sozinha a
  próxima fase.

### Key Entities

- **SpecState**: identidade, status, fase atual, revisão do schema e instante da
  última transição de uma spec.
- **PhaseTransition**: evento imutável que liga uma fase de origem a um destino
  permitido e registra quando e por qual comando ocorreu.
- **PhaseContract**: pré-condições e pós-condições exigidas para cada destino.
- **GateDecision**: veredito versionado de QA, score, findings, evidências e,
  quando aplicável, waiver formalizado.
- **SpecLocator**: número, `spec_id` ou branch usados para chegar a um único
  diretório canônico.

### Assumptions and Defaults

- `spec-meta.yaml` continua sendo a projeção atual e shell-legível do estado; o
  histórico é append-only e não substitui essa leitura rápida.
- O arquivo histórico nasce na primeira transição feita pelo contrato novo;
  specs arquivadas anteriores não são reescritas.
- A matriz padrão é linear, com apenas um retorno operacional:
  `specify -> plan -> tasks -> implement -> qa-gate -> archived` e
  `qa-gate -> implement`.
- O gate da spec 012 permanece compatível como registro histórico; novas
  decisões usam o schema vigente.
- Locks são locais à spec, têm falha explícita e nunca justificam avançar sem
  registrar estado.
- Nenhuma decisão de produto, waiver ou mudança de rota será automatizada.

### Out of Scope

- Remover ou reescrever a gordura BMAD inventariada na spec 012 (Etapa 3).
- Criar classificação adaptativa de risco ou orçamento de contexto (Etapa 3).
- Implementar worktrees, checkpoints do runner ou retomada autônoma (Etapa 4).
- Migrar ou alterar retroativamente o conteúdo de specs já arquivadas.
- Adicionar dependência externa para parsing ou validação de YAML/JSON.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% das transições permitidas e proibidas da matriz possuem
  fixture e resultado determinístico.
- **SC-002**: Em 100% das falhas simuladas, metadata e histórico permanecem
  byte a byte iguais ao estado anterior.
- **SC-003**: Nenhuma task mantida altera `current_phase` diretamente; todas
  usam a interface única de transição.
- **SC-004**: Número, `spec_id` e branch resolvem a mesma spec íntegra, enquanto
  ausência, ambiguidade e metadata divergente retornam falha.
- **SC-005**: Uma corrida completa com retorno `qa-gate -> implement` produz um
  histórico válido, ordenado e coerente com o estado final.
- **SC-006**: Gate e waiver válidos, inválidos e de versão desconhecida recebem
  o mesmo veredito em QA, archive e ship-ready.
- **SC-007**: 100% dos gates novos `PASS`/`WAIVED` sem evidência obrigatória são
  bloqueados; o gate histórico da spec 012 continua legível.
- **SC-008**: O diagnóstico central passa numa materialização limpa de `mosk/`
  sem dependências externas.
- **SC-009**: Self-tests existentes continuam verdes e os novos testes cobrem
  idempotência, concorrência e interrupção de escrita.
- **SC-010**: O pacote termina sem marcadores `NEEDS CLARIFICATION` e sem decisão
  de arquitetura ou produto pendente.
