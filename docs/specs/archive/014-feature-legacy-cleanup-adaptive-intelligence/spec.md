# Feature Specification: Limpeza do legado e inteligência adaptativa

**Feature Branch**: `feature/014-legacy-cleanup-adaptive-intelligence`
**Created**: 2026-08-15
**Status**: Draft
**Input**: Etapa 3 do roadmap de autonomia: remover gordura e padrões legados do BMAD, simplificar o happy path, consolidar tasks e schemas e introduzir classificação adaptativa de risco e orçamento de contexto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fluxo direto, sem cerimônia herdada (Priority: P1)

Como pessoa usando o MOSK, quero pedir um artefato ou avançar no pipeline em linguagem natural e receber o resultado diretamente, para não precisar atravessar menus numerados, confirmações mecânicas ou elicitação obrigatória quando a intenção já está clara.

**Why this priority**: A maior gordura percebida está no caminho principal. Retirá-la produz ganho imediato de objetividade sem depender das mudanças arquiteturais posteriores.

**Independent Test**: Executar os fluxos de criação documental e `full-spec` em fixtures claras e ambíguas; o caso claro termina sem menu e o ambíguo concentra apenas as decisões realmente bloqueantes em uma rodada de perguntas.

**Acceptance Scenarios**:

1. **Given** um pedido claro e contexto suficiente, **When** um agente cria um documento, **Then** ele gera o artefato sem apresentar menu `1-9`, sem exigir seleção de método e sem pedir confirmação intermediária.
2. **Given** um pedido com lacunas que mudariam materialmente o resultado, **When** o agente chega ao ponto de decisão, **Then** ele faz no máximo uma rodada agrupada de perguntas bloqueantes e continua após a resposta.
3. **Given** que o usuário pede explicitamente exploração avançada, **When** o agente inicia a elicitação, **Then** os métodos avançados permanecem disponíveis como modo opt-in e não contaminam o caminho padrão.
4. **Given** uma etapa irreversível ou uma dúvida real, **When** a automação alcança esse limite, **Then** ela pausa com contexto, recomendação e uma pergunta objetiva.

---

### User Story 2 - Superfície menor sem perda de capacidade (Priority: P1)

Como mantenedor do toolkit, quero classificar, reescrever, fundir ou remover cada task legada com rastreabilidade, para reduzir duplicação e vocabulário antigo sem quebrar capacidades públicas, rotas de agentes ou integrações existentes.

**Why this priority**: A redução precisa ser verificável. Apagar arquivos sem provar absorção apenas troca gordura por regressão.

**Independent Test**: Comparar o inventário canônico antes/depois, verificar referências e rotas de cada task e executar uma matriz de capacidades para as tasks reescritas e fundidas.

**Acceptance Scenarios**:

1. **Given** as 50 tasks existentes no início da etapa, **When** o inventário é reconciliado, **Then** cada task possui uma única disposição (`keep`, `rewrite`, `merge` ou `remove`), justificativa, consumidor e evidência de cobertura.
2. **Given** uma task marcada para `merge` ou `remove`, **When** a alteração é aplicada, **Then** sua capacidade está absorvida em um destino explícito, não há referência ativa quebrada e os testes equivalentes passam.
3. **Given** instruções ou schemas duplicados, **When** são consolidados, **Then** existe uma fonte canônica e os consumidores apontam para ela sem cópias divergentes.
4. **Given** uma referência BMAD em código ou documentação ativa, **When** a auditoria é executada, **Then** ela é removida, reescrita em linguagem MOSK ou consta de uma allowlist justificada de atribuição histórica/licença.

---

### User Story 3 - Profundidade proporcional ao risco (Priority: P2)

Como usuário do MOSK, quero que os agentes ajustem investigação, contexto e validação ao risco real da mudança, para tarefas simples serem rápidas e tarefas críticas receberem rigor suficiente.

**Why this priority**: Autonomia inteligente não é executar sempre o fluxo máximo; é usar a profundidade necessária de forma consistente e explicável.

**Independent Test**: Rodar uma matriz compartilhada de cenários simples, padrão, elevados e críticos por diferentes agentes e conferir perfil, orçamento de contexto, especialistas e validações selecionados.

**Acceptance Scenarios**:

1. **Given** uma mudança pequena, reversível, clara e coberta por testes, **When** ela é classificada, **Then** recebe perfil compacto e carrega apenas contexto diretamente relevante.
2. **Given** uma mudança que toca segurança, dados, operações irreversíveis ou múltiplos domínios, **When** ela é classificada, **Then** recebe perfil elevado ou crítico e exige os controles correspondentes.
3. **Given** o mesmo conjunto de sinais, **When** agentes diferentes aplicam o contrato, **Then** produzem a mesma classe mínima de risco e o mesmo piso de validação.
4. **Given** evidência insuficiente, **When** o risco não pode ser reduzido com segurança, **Then** o perfil sobe de forma conservadora e registra os sinais que motivaram a decisão.

---

### User Story 4 - Prompts compactos e fontes únicas (Priority: P2)

Como mantenedor, quero instruções curtas, compostas e testáveis, para reduzir custo de contexto, contradições e manutenção duplicada entre produto, agentes e skills.

**Why this priority**: A classificação adaptativa só gera economia se os componentes carregados também forem enxutos e sem repetição.

**Independent Test**: Medir o corpus-alvo antes/depois, auditar referências duplicadas e validar os espelhos em instalações isoladas.

**Acceptance Scenarios**:

1. **Given** exemplos extensos dentro de prompts operacionais, **When** a task é reescrita, **Then** o caminho principal mantém apenas regras e exemplos mínimos, com material aprofundado separado e carregado sob demanda.
2. **Given** uma regra compartilhada por múltiplos agentes, **When** ela muda, **Then** a alteração ocorre na fonte canônica e a sincronização atualiza todos os espelhos esperados.
3. **Given** uma instalação isolada do toolkit, **When** os fluxos essenciais são executados, **Then** nenhuma instrução depende acidentalmente de arquivos disponíveis apenas no repositório de desenvolvimento.

### Edge Cases

- Um pedido simples toca um arquivo sensível ou operação irreversível: o sinal mais severo prevalece sobre tamanho e clareza.
- Sinais de risco se contradizem ou faltam: o classificador escolhe o perfil mais conservador aplicável e expõe a justificativa.
- O usuário pede explicitamente uma dinâmica antiga de elicitação: a capacidade pode ser atendida pelo modo avançado opt-in, sem reintroduzir o menu no happy path.
- Uma task de fusão ainda possui consumidores ativos: a remoção falha e o inventário continua apontando a migração pendente.
- Uma ocorrência de “BMAD” é atribuição histórica, licença ou artefato arquivado: ela permanece apenas se estiver na allowlist de escopo e não influenciar comportamento operacional.
- Redução de prompt elimina um detalhe necessário: a matriz de capacidades deve detectar a regressão antes da remoção da fonte anterior.
- Um runtime não oferece a mesma ferramenta auxiliar: o contrato degrada para recursos portáveis do toolkit, sem depender de rede ou pacote novo.
- O workspace contém alterações locais fora da spec: geração, testes e sincronização preservam essas mudanças e limitam seus writes ao escopo declarado.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O toolkit MUST manter um inventário canônico das 50 tasks presentes no início desta etapa, reconciliado com a baseline da spec 012.
- **FR-002**: Cada item do inventário MUST declarar disposição única (`keep`, `rewrite`, `merge` ou `remove`), justificativa, consumidores, destino quando aplicável e evidência necessária para conclusão.
- **FR-003**: Uma task marcada como `merge` ou `remove` MUST NOT ser apagada antes de sua capacidade estar absorvida, suas referências ativas estarem migradas e seus testes equivalentes passarem.
- **FR-004**: O toolkit MUST tratar criação direta do artefato como comportamento padrão quando o pedido e o contexto forem suficientes.
- **FR-005**: O happy path MUST NOT exigir menus numerados, escolha obrigatória de técnica de elicitação ou confirmação mecânica entre etapas reversíveis.
- **FR-006**: Quando faltarem decisões materialmente bloqueantes, o fluxo MUST agrupá-las em no máximo uma rodada de perguntas antes de prosseguir.
- **FR-007**: `advanced-elicitation` MUST permanecer disponível apenas por solicitação explícita do usuário ou por entrada explícita de um fluxo especializado documentado.
- **FR-008**: Flags legadas como `elicit: true` MUST NOT funcionar como hard stop automático no caminho padrão.
- **FR-009**: O toolkit MUST preservar pausas humanas para dúvida real, mudança de escopo material e ação irreversível.
- **FR-010**: O toolkit MUST fornecer um contrato adaptativo único, compartilhado pelos agentes, para classificar mudanças em perfis `compact`, `standard`, `elevated` e `critical`.
- **FR-011**: A classificação MUST considerar ao menos escopo/complexidade, quantidade de domínios afetados, reversibilidade, superfície de segurança ou dados, força dos testes/evidências e ambiguidade do pedido.
- **FR-012**: Sinais críticos de segurança, dados ou irreversibilidade MUST estabelecer um piso que não possa ser reduzido por sinais de simplicidade.
- **FR-013**: O contrato MUST mapear cada perfil para orçamento de contexto, profundidade de inspeção, especialistas exigidos e piso de validação.
- **FR-014**: O orçamento de contexto MUST ser expresso por categorias e fontes permitidas/obrigatórias, sem depender de contagem de tokens específica de um provedor.
- **FR-015**: A decisão adaptativa MUST ser explicável por sinais observáveis e reproduzível por diferentes agentes para a mesma fixture.
- **FR-016**: Na ausência de evidência suficiente, a política MUST escolher conservadoramente o perfil mais alto aplicável.
- **FR-017**: Instruções, schemas e contratos comuns MUST possuir uma fonte canônica no produto; cópias divergentes MUST ser eliminadas.
- **FR-018**: Tasks reescritas MUST manter o procedimento principal curto e mover exemplos extensos ou material raro para referências carregadas sob demanda.
- **FR-019**: Referências operacionais e vocabulário herdado do BMAD MUST ser removidos ou traduzidos para conceitos MOSK.
- **FR-020**: Atribuições históricas, licenças e arquivos arquivados MAY permanecer quando isolados por uma allowlist explícita e sem efeito no comportamento ativo.
- **FR-021**: As três candidatas históricas a fusão (`map-project`, `review-story` e `webdesign-output`) MUST ter destino, cobertura e migração validados antes de qualquer remoção.
- **FR-022**: Tasks hoje sem rota pública MUST ser integradas a um agente/skill apropriado ou removidas com justificativa e prova de não uso.
- **FR-023**: A redução MUST preservar os contratos estabilizados nas specs 012 e 013: separação produto/local, espelhos, resolução determinística de spec, máquina de estados, histórico e gates fail-closed.
- **FR-024**: O toolkit MUST operar em Bash e zsh suportados, sem nova dependência externa obrigatória e sem acesso de rede para classificar risco ou orçamento.
- **FR-025**: Mudanças na fonte `mosk/.claude/` MUST ser sincronizadas para `.claude/` e verificadas por diff-check conforme o contrato do repositório.
- **FR-026**: O toolkit MUST incluir testes de regressão para happy path, opt-in avançado, inventário/fusões, classificação adaptativa e instalações isoladas.
- **FR-027**: O toolkit MUST atualizar documentação e ajuda pública para explicar o fluxo direto e a profundidade adaptativa sem expor cerimônia interna desnecessária.
- **FR-028**: A etapa MUST NOT introduzir o plano de execução por worktrees, checkpoints de runner ou recuperação automática planejados para a Etapa 4.

### Key Entities

- **Task Disposition**: Decisão rastreável sobre uma task existente, com ação, motivo, consumidores, destino e evidência de conclusão.
- **Capability Route**: Ligação entre uma capacidade pública, o agente/skill que a expõe e a task ou contrato canônico que a implementa.
- **Change Profile**: Resultado explicável da classificação adaptativa, composto por perfil, sinais observados, pisos aplicados e validações requeridas.
- **Context Budget**: Política por perfil que define quais fontes carregar, profundidade permitida e quando expandir o contexto.
- **Legacy Allowance**: Exceção justificada para referência histórica ou legal que pode permanecer sem participar da operação do toolkit.

## Assumptions

- O inventário da spec 012 continua sendo a baseline de 50 tasks e será reconciliado contra o estado atual antes de qualquer edição estrutural.
- A interface pública continua baseada em linguagem natural e skills; compatibilidade significa preservar capacidades, não menus ou nomes internos antigos.
- “Orçamento de contexto” será determinístico por categorias de fontes e profundidade, não por tokens exatos do modelo.
- A política adaptativa recomenda profundidade e controles, mas nunca remove os limites humanos para ações irreversíveis.
- A Etapa 3 pode reduzir arquivos e linhas; não precisa preservar compatibilidade de paths internos classificados como legados depois que todos os consumidores forem migrados.

## Out of Scope

- Implementar o runner paralelo, worktrees isoladas por slice, checkpoints de execução ou retomada automática da Etapa 4.
- Alterar a máquina de estados e o histórico determinístico entregues pela spec 013, exceto para consumir seus contratos existentes.
- Redesenhar a experiência visual do toolkit, publicar releases ou alterar provedores de deploy.
- Remover atribuições legais ou reescrever documentação arquivada apenas para eliminar ocorrências textuais.
- Mudar capacidades de domínio do Bench, Planner, QA ou Security além da simplificação de interação, composição e carregamento de contexto.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das 50 tasks da baseline possuem disposição, rota e evidência verificáveis; nenhuma task ativa fica órfã.
- **SC-002**: Fixtures do happy path de criação documental e `full-spec` terminam sem menu numerado e com no máximo uma rodada agrupada de perguntas bloqueantes.
- **SC-003**: 100% das candidatas a fusão removidas possuem zero referência ativa quebrada e passam a matriz de capacidade no destino.
- **SC-004**: O corpus das 18 tasks classificadas como `rewrite` na baseline reduz em pelo menos 30% suas linhas operacionais, excluindo frontmatter, atribuição/licença e referências movidas para material sob demanda.
- **SC-005**: Uma matriz compartilhada de fixtures obtém 100% de concordância entre consumidores sobre perfil mínimo, orçamento de contexto e piso de validação.
- **SC-006**: A auditoria de legado encontra zero referência BMAD operacional fora da allowlist documentada.
- **SC-007**: Todos os selftests, doctors, verificações de espelho e testes isolados existentes continuam passando em Bash e zsh suportados.
- **SC-008**: Nenhuma nova dependência obrigatória ou acesso de rede é necessário para executar a classificação adaptativa.
- **SC-009**: Os contratos de estado, gates e segurança das specs 012 e 013 permanecem cobertos por regressão, sem redução do comportamento fail-closed.
- **SC-010**: Toda regra compartilhada alterada possui uma única fonte canônica e zero cópia divergente detectada nos consumidores ativos.

---
**Arquivado em:** 2026-08-19
**Status final:** Concluído
**Promoções aplicadas:** nenhuma — a spec não declarou nenhum `promote:`. O `contracts/adaptive-work-contract.md` já havia sido materializado em `mosk/.claude/mosk/data/adaptive-work-contract.md` durante a implementação; a cópia aqui congela como registro de origem.
**Nota:** archive retroativo. A spec foi mesclada no `master` em 2026-08-16 ainda na fase `qa-gate`, sem passar por esta etapa — nada invocou o `check-ship-ready.sh`, que existia exatamente para impedi-lo. O gate (`PASS`, score 100, 0 FAIL, 0 CONCERNS) e as 62 tasks já estavam completos na data do merge; o que faltava era o registro. O caso virou fixture de regressão na spec 016 (T018), e a lacuna que o permitiu está tratada no [ADR-0021](../../016-refactor-prompt-first-toolkit/architecture/adr-0021-declarative-rule-minimal-shell.md), decisão 5: garantia sem chamador nomeado não conta como garantia.
