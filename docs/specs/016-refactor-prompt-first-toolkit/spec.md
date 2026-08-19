# Feature Specification: Toolkit prompt-first

**Feature Branch**: `refactor/016-prompt-first-toolkit`
**Created**: 2026-08-19
**Status**: Draft
**Input**: Remodelar o toolkit para ser prompt-first: regra de pipeline em YAML declarativo lido por prompt, Bash restrito a git, geração de arquivos derivados e uma validação única.

## Contexto

O MOSK é um produto de prompts distribuído por `npx degit`. A composição atual não reflete isso:

| camada | linhas no `master` | |
|---|---:|---|
| Bash (sem `payload-*`) | 7.912 | 42% |
| Templates | 5.658 | 30% |
| Tasks (prompts) | 3.584 | 19% |
| Agentes | 1.461 | 8% |

Shell sozinho pesa mais que prompts e agentes somados. Dentro dele, **1.726 linhas** são `selftest-*.sh` — existem só para testar os outros scripts — e **1.323** são `common.sh`, com 39 funções. Somados, 38% do shell é infraestrutura sustentando infraestrutura, e **2.607 linhas (33%) não são citadas por nenhum prompt, skill, hook ou CI**.

A tendência é o dado mais forte que o estoque: **a branch da spec 015, sozinha, leva o Bash de 7.912 para 14.633 linhas**. Uma única spec quase dobrou o shell do toolkit.

A causa não foi descuido. A Etapa 2 do [roadmap de autonomia](../../discovery/toolkit-autonomy-assessment-roadmap.md) partiu de uma premissa correta — *regra escrita em prompt não é garantia* — e generalizou a conclusão: *então toda regra vira Bash verificável*. A partir daí cada regra do MOSK virou candidata a script, e cada script virou candidato a self-test em dois shells, dois sistemas operacionais, com e sem git.

O ponto extremo está na spec 015. Ela produziu um ADR que define uma **gramática YAML canônica própria** e uma task que valida o parser YAML escrito em Bash contra o PyYAML — 273 comparações sobre corpus gerado por produto cartesiano. Aquele ADR registra **treze voltas de correção na mesma família de defeitos** e três emendas ao próprio texto (`QA-3 → QA-7 → QA-10 → QA-14 → QA-17 → SEC-11 → SEC-18 → SEC-19 → SEC-21`), todas nascidas de ler YAML em shell. E o ponto de chegada dele recusa qualquer linha que contenha `"`, `'`, `{`, `[`, `|` ou `>` — ou seja, o formato deixou de ser YAML para caber no leitor. O [ADR-0021](./architecture/adr-0021-declarative-rule-minimal-shell.md) trata essa inversão: foi a escolha do leitor que determinou o que o formato pôde ser.

Há uma segunda evidência, mais direta. A spec 014 foi **mesclada no `master` ainda em `qa-gate`**, sem archive — exatamente o que `check-ship-ready.sh`, construído nas specs 012 e 013 para ser a fonte única de "spec fechada", existia para impedir. A garantia escrita em Bash não se aplicou sozinha, porque nada a chamou. Isso é o custo real do mecanismo escolhido: ele acrescentou milhares de linhas de superfície de manutenção sem entregar a garantia que justificava a superfície.

Esta spec não abandona as garantias. Ela troca a camada onde elas moram: **regra em YAML declarativo, aplicação em prompt, Bash só onde o agente genuinamente não alcança** — corrida de numeração no remoto, geração de arquivos derivados e uma verificação única.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A regra do pipeline vive em um arquivo legível (Priority: P1)

Como pessoa mantendo o MOSK, quero que fases, transições válidas, pré/pós-condições e artefatos obrigatórios estejam declarados em um único arquivo YAML, para poder ler e alterar a regra sem abrir um script de shell e sem escrever um teste que prove que o shell continua interpretando o YAML corretamente.

**Why this priority**: É a fundação. Enquanto a regra estiver codificada dentro de `transition-spec-phase.sh` e `common.sh`, nenhuma redução de Bash é possível sem perder a regra junto.

**Independent Test**: Ler `pipeline.yaml` e confirmar que ele descreve as 6 fases, as arestas válidas e os artefatos exigidos por fase; alterar uma aresta no YAML e verificar que o comportamento do pipeline muda sem nenhuma edição de script.

**Acceptance Scenarios**:

1. **Given** o `pipeline.yaml` publicado, **When** um mantenedor precisa saber quais transições são válidas a partir de `qa-gate`, **Then** a resposta está em um bloco declarativo do arquivo, sem precisar ler código.
2. **Given** uma fase com artefatos obrigatórios declarados, **When** a task da fase seguinte roda, **Then** ela confere os artefatos contra o YAML em vez de repetir a lista no próprio prompt.
3. **Given** a exceção `qa-gate -> implement` restrita a `apply-qa-fixes`, **When** o YAML é lido, **Then** essa restrição aparece como dado na aresta, não como condicional em script.
4. **Given** uma regra alterada no `pipeline.yaml`, **When** nenhum script é tocado, **Then** o comportamento novo vale para todas as tasks que leem o arquivo.

---

### User Story 2 - Quatro utilidades de Bash, e nada além (Priority: P1)

Como pessoa instalando o MOSK em um projeto, quero que o toolkit traga o mínimo de shell, para que a instalação não dependa de o meu ambiente reproduzir o comportamento de bash e zsh em macOS e Linux, com e sem git, com e sem PyYAML.

**Why this priority**: É onde estão as ~6.400 linhas a remover, e é o custo que o consumidor paga hoje em toda instalação.

**Independent Test**: Contar as linhas de `scripts/*.sh` após o corte e verificar que cada script remanescente é citado por ao menos um prompt ou por um guardrail declarado.

**Acceptance Scenarios**:

1. **Given** o toolkit remodelado, **When** os scripts são inventariados, **Then** restam apenas criação de spec, sincronização de derivados, validação única, reinstalação e sync do vendor Hallmark.
2. **Given** o corte aplicado, **When** as linhas de Bash são somadas, **Then** o total fica em no máximo 1.500.
3. **Given** um script remanescente, **When** se pergunta quem o chama, **Then** existe um prompt, uma skill ou um guardrail que o cita nominalmente.
4. **Given** os `selftest-*.sh` removidos, **When** se pergunta o que garante o comportamento, **Then** a resposta é o `pipeline.yaml` mais a validação única — não uma suíte que testa shell.
5. **Given** uma regra que hoje mora em script e não tem equivalente declarativo, **When** o corte é planejado, **Then** ela é migrada antes da remoção, nunca removida com a promessa de migrar depois.

---

### User Story 3 - Uma validação, não seis auditores (Priority: P1)

Como pessoa operando o pipeline, quero um comando único que responda "este estado é válido?", para não precisar lembrar qual dos auditores cobre qual pedaço nem descobrir tarde que nenhum deles foi chamado.

**Why this priority**: É a falha concreta que deixou a 014 entrar no `master` em `qa-gate`. Garantia que depende de alguém lembrar de invocá-la não é garantia.

**Independent Test**: Rodar a validação sobre fixtures de spec válida, spec sem gate, spec com transição inválida e referência interna quebrada, conferindo veredito e mensagem em cada caso.

**Acceptance Scenarios**:

1. **Given** `doctor.sh`, `check-prerequisites.sh`, `check-ship-ready.sh` e `audit-docs-paths.sh`, **When** a remodelagem termina, **Then** existe um `validate.sh` único que cobre os quatro casos de uso lendo o `pipeline.yaml`.
2. **Given** uma spec em `qa-gate` sem gate `PASS` ou `WAIVED` formalizado, **When** a validação roda, **Then** ela reprova e nomeia o que falta.
3. **Given** a validação disponível, **When** se pergunta quem a chama, **Then** existe ao menos um ponto de invocação automático — não apenas a disciplina de quem opera.
4. **Given** a validação rodando em uma instalação limpa, **When** não há PyYAML, npm ou pip, **Then** ela funciona assim mesmo.

---

### User Story 4 - O runner usa a primitiva do runtime, não uma reimplementação (Priority: P2)

Como pessoa consentindo uma corrida autônoma, quero que isolamento, paralelismo e retomada usem o que o runtime já oferece, para que o runner pare de carregar uma reimplementação em shell daquilo que a plataforma entrega pronta.

**Why this priority**: Depende de US1 e US2 estarem resolvidas, mas é o que converte o trabalho da 015 em algo sustentável em vez de descartado.

**Independent Test**: Executar uma corrida em fixture usando a primitiva nativa de isolamento, interrompê-la, retomá-la e verificar que nenhuma unidade é reimplementada nem recommitada.

**Acceptance Scenarios**:

1. **Given** o `execution-plan.yaml` colhido da spec 015, **When** o runner precisa do plano, **Then** ele é escrito pelo agente a partir do `tasks.md`, não gerado por script.
2. **Given** um runtime que oferece isolamento por subagente, **When** a onda roda, **Then** o runner usa essa primitiva e declara no preflight que o paralelismo é real.
3. **Given** um runtime sem isolamento, **When** a onda roda, **Then** o runner cai em sequencial e declara isso — a honestidade do preflight, exigida pelo ADR-0019, é preservada.
4. **Given** uma corrida interrompida, **When** ela é retomada, **Then** o estado vem do `run-log.md` e do frontmatter, sem `run-state.yaml` com parser próprio.
5. **Given** os requisitos da spec 015, **When** a 016 termina, **Then** as cinco user stories daquela spec continuam atendidas — o que mudou foi o mecanismo, não a exigência.

---

### User Story 5 - A premissa antiga não volta pela porta dos fundos (Priority: P2)

Como pessoa que vai planejar a próxima spec do MOSK, quero que o roadmap e os ADRs reflitam a direção nova, para não repetir o padrão que produziu quatro specs de infraestrutura.

**Why this priority**: Sem isso, o roadmap vigente continua instruindo o contrário e a spec seguinte recomeça o ciclo.

**Independent Test**: Ler o roadmap e os ADRs após a remodelagem e confirmar que nenhum documento vigente instrui a mover regra para Bash.

**Acceptance Scenarios**:

1. **Given** o ADR que reverte a premissa, **When** ele é publicado, **Then** o ADR-0020 aparece como superseded, com a razão registrada.
2. **Given** as Etapas 2 a 5 do roadmap de autonomia, **When** a remodelagem termina, **Then** elas foram reescritas ou marcadas como substituídas.
3. **Given** um mantenedor abrindo a próxima spec, **When** ele lê os documentos vigentes, **Then** a regra de decisão "isto vira prompt, YAML ou script?" está declarada e é aplicável sem interpretação.

---

### Edge Cases

- Uma regra hoje aplicada por script que **não** tem equivalente declarativo viável — a spec precisa nomeá-la explicitamente em vez de removê-la em silêncio.
- Projetos consumidores que já instalaram a versão anterior e têm `.mosk-worktrees`, `run-state.yaml` ou scripts órfãos no disco — `reset-install.sh` já cobre órfãos, mas o estado gerado precisa de tratamento declarado.
- A 015 fica com branch aberta e trabalho não mesclado; o que se colhe dela precisa ser transportado antes de a branch ser abandonada.
- A 014 está mesclada em `qa-gate`: seu fechamento formal é pré-condição para o `master` voltar a ser um estado válido segundo a própria regra.
- `payload-*.sh` (737 linhas) pertence ao modo bench/deploy, não ao pipeline — está fora deste escopo e não deve ser cortado por arrasto.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O toolkit MUST declarar fases, transições válidas, pré/pós-condições e artefatos obrigatórios em um `pipeline.yaml` único.
- **FR-002**: Nenhuma task MUST repetir em prosa uma regra já declarada no `pipeline.yaml`; ela referencia o arquivo.
- **FR-003**: O conjunto de scripts MUST se restringir a: criação de spec, sincronização de derivados, validação única, reinstalação e sync do vendor.
- **FR-004**: O total de linhas em `scripts/*.sh` MUST ficar em no máximo 1.500, excluído `payload-*`.
- **FR-005**: Todo script remanescente MUST ser citado nominalmente por um prompt, skill ou guardrail declarado.
- **FR-006**: `validate.sh` MUST cobrir os casos de uso hoje divididos entre `doctor`, `check-prerequisites`, `check-ship-ready` e `audit-docs-paths`, lendo o `pipeline.yaml`.
- **FR-007**: `validate.sh` MUST funcionar sem PyYAML, npm ou pip.
- **FR-008**: A validação MUST ter ao menos um ponto de invocação automático, não apenas manual.
- **FR-009**: Toda regra migrada MUST ter equivalente declarativo publicado antes de o script correspondente ser removido.
- **FR-010**: O `execution-plan.yaml` MUST ser escrito pelo agente a partir do `tasks.md`, não gerado por script.
- **FR-011**: O runner MUST usar a primitiva de isolamento do runtime quando ela existir, e declarar o modo no preflight.
- **FR-012**: O estado da corrida MUST viver em `run-log.md` e frontmatter, sem formato que exija parser próprio.
- **FR-013**: Um ADR MUST reverter a premissa da Etapa 2 e marcar o ADR-0020 como superseded.
- **FR-014**: As Etapas 2 a 5 do roadmap de autonomia MUST ser reescritas ou marcadas como substituídas.
- **FR-015**: A regra de decisão "prompt, YAML ou script?" MUST estar declarada e ser aplicável sem interpretação.
- **FR-016**: Os requisitos das cinco user stories da spec 015 MUST permanecer atendidos ao fim da 016.

### Key Entities

- **`pipeline.yaml`** — fonte única da regra do pipeline: fases, arestas, condições, artefatos.
- **`execution-plan.yaml`** — plano da corrida autônoma, escrito pelo agente; formato colhido da spec 015.
- **`validate.sh`** — verificador único; lê o `pipeline.yaml` e responde sobre um estado.
- **Regra de decisão de camada** — critério publicado que diz se uma regra nova vira prompt, YAML ou script.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `scripts/*.sh` soma no máximo 1.500 linhas, excluído `payload-*` — redução de ao menos 80% sobre as 7.912 do `master`.
- **SC-002**: Zero arquivos `selftest-*.sh` no template.
- **SC-003**: 100% dos scripts remanescentes têm chamador nominal identificado.
- **SC-004**: Uma spec não pode ser mesclada em fase diferente de `archived` sem que a validação reprove — verificado pelo caso real da 014.
- **SC-005**: As 6 fases e todas as arestas válidas são obtidas lendo um único arquivo.
- **SC-006**: Uma corrida autônoma interrompida é retomada sem commit duplicado, sem `run-state.yaml`.
- **SC-007**: Nenhum documento vigente instrui a mover regra de prompt para Bash.
- **SC-008**: Uma instalação limpa executa a validação sem dependência externa.

## Assumptions

- O runtime alvo oferece isolamento por subagente (Claude Code oferece hoje); onde não oferecer, sequencial declarado é aceitável — mesma postura do ADR-0019.
- A essência herdada do BMAD que se preserva são personas, artefatos duráveis e gate independente — todas vivem em agentes e templates, fora do escopo do corte.
- `payload-*.sh` e o vendor Hallmark seguem regime próprio e não entram na contagem.

## Out of Scope

- Modo bench, deploy Payload/Railway e os scripts `payload-*`.
- Alteração de personas, missão dos agentes ou do conjunto de 12 agentes.
- Mudança no layout `docs/` ou na convenção de promoção.
- Reescrita dos templates de documento (`*-tmpl.yaml`), exceto os do runner.
