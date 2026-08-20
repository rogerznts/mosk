# Avaliação funcional e roadmap de autonomia do MOSK

**Data:** 2026-08-15  
**Escopo avaliado:** `mosk/.claude/` — template distribuível do toolkit  
**Objetivo:** tornar o MOSK mais autônomo, objetivo, inteligente, confiável e
simples de manter.

## Contexto

O MOSK já tem uma arquitetura conceitual forte: papéis especializados, pipeline
rastreável, documentação durável, QA independente e limites claros para ações
irreversíveis. O problema principal não é falta de funcionalidades. É a distância
entre as regras descritas nos prompts e as garantias efetivamente aplicadas pelo
toolkit.

Hoje o MOSK é funcional e bem estruturado para operação assistida, mas ainda não
é suficientemente determinístico para autonomia confiável. Regras críticas de
estado, paralelismo, gate, archive, seleção de contexto e recuperação de falhas
ainda dependem da interpretação do agente.

## Decisão de produto: MOSK primeiro, legado sem imunidade

O MOSK não deve preservar padrões antigos apenas porque vieram do BMAD, do
SpecKit ou de versões anteriores do próprio toolkit.

BMAD e SpecKit permanecem como **linhagem e fonte de aprendizado**, não como
contrato de compatibilidade. A implementação atual deve ser julgada pelo que
serve ao MOSK hoje.

Portanto:

- menus extensos não permanecem por tradição;
- elicitação seção por seção não é o comportamento padrão;
- workflows longos, repetitivos ou cerimoniais devem ser encurtados;
- exemplos gigantes dentro de tasks devem virar referências pequenas ou
  fixtures;
- schemas, regras e instruções duplicadas devem ganhar fonte única;
- vocabulário interno não deve vazar para a saída ao usuário;
- tasks sem rota, obsoletas ou sobrepostas devem ser integradas ou removidas;
- referências a camadas antigas devem ser eliminadas;
- nenhuma compatibilidade herdada justifica comprometer autonomia,
  objetividade, confiabilidade ou clareza.

### Regra de modernização

Para cada agente, task, template, script ou checklist herdado, a revisão deve
responder:

1. Esta peça ainda resolve um problema atual do MOSK?
2. Está na menor forma capaz de resolver esse problema?
3. A regra precisa viver em prompt ou pode ser verificada deterministicamente?
4. Duplica alguma fonte de verdade?
5. Interrompe o usuário quando uma decisão segura poderia ser tomada por padrão?
6. Funciona de forma explícita e verificável em Claude Code e Codex?

Se as respostas não forem satisfatórias, a peça deve ser reescrita, consolidada
ou removida. A presunção é a favor da simplicidade, não da conservação.

## Inventário funcional

O template avaliado possui:

- 12 agentes;
- 50 tasks;
- 17 scripts;
- 30 templates principais;
- 6 checklists;
- dados de elicitação, testes, preferências técnicas, contrato de saída e o
  vendor Hallmark.

As capacidades cobertas são:

- instalação, atualização, boot e migração;
- discovery, PRD, arquitetura, UX e UI;
- pipeline `specify → plan → tasks → implement → qa-gate → archive`;
- stories, épicos, checklists e artefatos complementares;
- implementação sequencial ou delegada;
- QA, risco, NFR, rastreabilidade e segurança;
- documentação base e por spec, com promoção no archive;
- Bench para usuários não técnicos;
- deploy Payload/Railway;
- runner autônomo `/mosk-orq`;
- integração com Claude Code e Codex;
- sincronização agente → skill e geração do `AGENTS.md`.

## Avaliação de maturidade

| Dimensão | Nota | Diagnóstico |
|---|---:|---|
| Cobertura funcional | 4/5 | Ampla superfície funcional e bons papéis especializados |
| Organização e rastreabilidade | 4/5 | Specs, fases, gates, ADRs, promoções e índices |
| Objetividade | 2/5 | Tasks antigas ainda exigem menus e elicitação excessiva |
| Autonomia | 2/5 | O runner existe, mas depende demais da interpretação do agente |
| Inteligência contextual | 3/5 | Bons papéis e contexto durável, pouca decisão estruturada por evidência |
| Confiabilidade | 2/5 | Transições, archive, referências e dependências não estão totalmente validados |
| Manutenção | 3/5 | Boa modularização, com duplicações, drift e conteúdo legado |
| Observabilidade | 3/5 | Gate e logs existem, mas parte do estado segue não estruturada |

## Fundações que devem ser preservadas

- separação entre `mosk/` distribuível e ambiente local da raiz;
- agente como fonte única e skill como wrapper;
- estado durável por spec;
- QA separado da implementação;
- reserva atômica dos números de spec;
- limites explícitos para ações irreversíveis;
- contrato de saída legível;
- sincronização e pruning de agentes e skills;
- scripts idempotentes e operações destrutivas com `--dry-run`;
- documentação base × spec e promoção no archive;
- Hallmark vendorizado com processo próprio de atualização.

## Achados prioritários

### P0 — O pipeline pode declarar sucesso sem gate aprovado

`update_spec_phase` registra a fase, mas não valida transições ou evidências. O
`archive` verifica tasks e artefatos, porém não exige `gate: PASS` nem um
`WAIVED` formalizado. Depois disso, `check-ship-ready.sh` considera suficiente a
fase estar `archived`.

**Risco:** uma spec pode ser arquivada e considerada pronta para merge sem ter
passado pelo QA.

**Direção:** criar máquina de estados determinística, exigir evidências por
transição e impedir archive sem gate válido.

### P0 — O runner autônomo ainda não tem contrato executável

O `/mosk-orq` aceita um número ou id de spec, mas seu roteiro resolve o trabalho
pelo branch atual. O paralelismo também é ambíguo: `[P]` qualifica tasks, enquanto
o runner distribui user stories inteiras.

Worktree, branch do worker, commit, merge, atribuição de falha, retomada e cleanup
são descritos principalmente em prosa. A primitiva de subagente e isolamento
também não é equivalente entre os runtimes.

**Risco:** comportamento diferente entre execuções e runtimes, conflitos,
trabalho duplicado e retomadas inseguras.

**Direção:** gerar um plano de execução estruturado e adicionar helpers
determinísticos para o ciclo de vida da corrida.

### P0 — A validação interna não é autocontida

`audit-docs-paths.sh` depende de `yaml` em Python, mas o toolkit não declara ou
instala PyYAML. Numa instalação sem essa biblioteca, o auditor falha antes de
auditar.

Também foram observadas referências a camadas antigas, extensões ausentes,
exemplo de timestamp inválido e divergências na contagem documentada de agentes.

**Direção:** criar um verificador autocontido, sem dependências não declaradas,
que cubra referências, schemas, sincronização, scripts e instalação materializada.

### P1 — A UX contradiz o objetivo de objetividade

Agentes atuais orientam execução direta e poucas perguntas, mas `create-doc.md`
exige interação seção por seção, desabilita otimizações de eficiência e apresenta
menus de elicitação obrigatórios.

**Risco:** excesso de turnos, gasto de contexto, documentos prolixos e
experiência inconsistente.

**Direção:** criação direta por padrão, uma rodada agrupada de perguntas apenas
quando necessária e elicitação avançada exclusivamente opt-in.

### P1 — A inteligência contextual ainda é pouco adaptativa

Os agentes possuem regras de carregamento, mas não compartilham um mecanismo
para classificar escopo, risco, reversibilidade, superfície de segurança,
evidências disponíveis e profundidade necessária.

**Direção:** introduzir uma classificação comum de mudança que governe contexto,
agentes, validações e autonomia.

### P1 — Existe superfície herdada em excesso

As tasks somam aproximadamente 7.200 linhas. Parte delas mantém menus, exemplos
extensos, instruções repetidas, schemas duplicados e padrões antigos de BMAD.
Há tasks sem rota clara e referências que sobreviveram à remoção de camadas
anteriores.

**Direção:** executar uma revisão sistemática de todas as 50 tasks usando a
regra de modernização deste documento.

## Arquitetura-alvo

### 1. Estado determinístico

Criar uma API única para o estado do pipeline:

```text
resolve-spec
validate-transition
transition-spec
validate-gate
validate-archive
```

Nenhuma task deve editar `current_phase` diretamente. Toda transição deve
registrar origem, destino, timestamp e evidência.

### 2. Planejamento legível por humanos e máquinas

Preservar `spec.md`, `plan.md` e `tasks.md`, mas gerar também:

```text
execution-plan.yaml
evidence.yaml
decision-log.yaml
```

`execution-plan.yaml` deve declarar:

- unidades de trabalho;
- tasks de cada unidade;
- arquivos permitidos;
- dependências;
- grupos de paralelismo;
- critérios de aceite;
- comandos de validação;
- risco e superfície sensível.

### 3. Autonomia progressiva

- **A0 — consultivo:** mudanças de rota sempre pedem decisão humana.
- **A1 — autônomo dentro de uma fase:** apenas ações reversíveis e já aprovadas.
- **A2 — entrega autônoma:** `/mosk-orq`, com consentimento por corrida.
- **A3 — proibido sem humano:** deploy, migration, push, exclusão, waiver ou
  mudança de regra de produto.

### 4. Inteligência baseada em evidências

Antes de agir, classificar:

- escopo e complexidade;
- arquivos e domínios afetados;
- risco técnico e de produto;
- superfície de segurança;
- existência de testes;
- clareza dos critérios;
- reversibilidade;
- força das evidências disponíveis.

Essa classificação deve governar automaticamente o contexto carregado, a
profundidade do plano, os especialistas necessários e as validações.

### 5. Contrato explícito por runtime

O MOSK não deve fingir que Claude Code e Codex oferecem primitivas idênticas.
Deve detectar capacidades e escolher um modo suportado:

- paralelo com isolamento real;
- paralelo sem isolamento, somente quando não houver conflito de escrita;
- sequencial como fallback seguro.

O resultado funcional pode ser equivalente; o mecanismo precisa ser declarado.

## Roadmap

### Etapa 1 — Estabilização ⟶ **entregue** (spec 012)

**Estimativa:** 2–3 dias.

- remover a dependência de PyYAML do auditor;
- corrigir referências quebradas e timestamps;
- unificar contagem e nomenclatura dos agentes;
- impedir archive sem gate válido;
- criar `mosk doctor` para validar instalação e contratos;
- consolidar os self-tests num comando único.

**Critério de saída:** uma instalação limpa executa todos os validadores sem
dependência externa ou referência quebrada.

### Etapa 2 — Núcleo determinístico ⟶ **SUBSTITUÍDA** (2026-08-20)

> **A premissa desta etapa foi revertida pelo [ADR-0021](../architecture/adr/adr-0021-declarative-rule-minimal-shell.md).**
>
> O texto original dizia: *implementar máquina de estados, criar schema para
> gate e waiver, centralizar resolução de spec, validar pré e pós-condições por
> fase, gerar histórico estruturado, fazer `check-ship-ready` verificar gate.*
>
> As **garantias** estavam certas e foram todas entregues. O **mecanismo** —
> codificar cada uma em Bash — estava errado, e o custo apareceu medido: entre
> as specs 012 e 015 o toolkit foi de ~2.800 para 14.633 linhas de shell, das
> quais 57% existia para sustentar o próprio shell. A spec 015 sozinha quase
> dobrou o total.
>
> O ponto de chegada é o argumento: para que o shell lesse aqueles arquivos com
> segurança, o ADR-0020 precisou recusar qualquer linha contendo `"`, `'`, `{`,
> `[`, `|` ou `>`. Nesse ponto o formato deixou de ser YAML. **A escolha do
> leitor determinou o que o formato pôde ser.**
>
> E a garantia que justificava tudo isso não se aplicou: a spec 014 chegou ao
> `master` em `qa-gate`, com o `check-ship-ready.sh` instalado, correto e nunca
> invocado.

**Substituída por:** regra em `pipeline.yaml`, lida pelo agente; script apenas
onde o agente não alcança. Entregue na spec 016.

### Etapa 3 — Remoção do legado e inteligência adaptativa

*Entregue na spec 014.* O inventário das 50 tasks, a remoção de menus e
elicitação obrigatória, e a classificação adaptativa comum estão feitos. O que
permanece válido desta etapa é a **regra de modernização** declarada acima, que
não depende da premissa revertida.

### Etapa 4 — Runner autônomo confiável ⟶ **REFEITA** (spec 016)

> A spec 015 atacou esta etapa com o mecanismo da Etapa 2 e foi interrompida em
> `implement` (32/44 tasks), depois de treze voltas na mesma família de defeitos.
>
> Os **requisitos** continuam valendo, todos os cinco, e foram reimplementados na
> spec 016 sobre outra base — plano escrito pelo agente, estado no front-matter
> do `run-log.md`, isolamento pela primitiva do runtime. A conferência cenário a
> cenário está em `docs/specs/016-refactor-prompt-first-toolkit/spec-015-requirements-check.md`.

### Etapa 5 — Avaliação contínua

**Continua válida e é a próxima.** Nada nela dependia da premissa revertida: os
cenários reprodutíveis (feature pequena, refactor, mudança com autenticação, spec
ambígua, conflito de arquivos, teste quebrado, ausência de suíte, migration
proibida, gate estagnado, retomada após falha) valem igualmente para um toolkit
prompt-first — e valem mais, porque agora há menos shell entre o cenário e o
comportamento observado.

Uma adição, vinda do que a 016 aprendeu: **os cenários devem cobrir também a
degradação declarada** — runtime sem isolamento, instalação sem parser YAML,
projeto sem git. São os pontos onde o toolkit escolhe funcionar pior em vez de
mentir, e nenhum deles tem cobertura hoje.

## Métricas de sucesso

- zero archive sem gate válido;
- 100% das referências internas válidas;
- pelo menos 70% dos cenários reversíveis concluídos sem intervenção além do
  preflight;
- nenhuma ação irreversível executada sem humano;
- no máximo uma pergunta agrupada no happy path;
- mesma decisão de gate para a mesma evidência;
- redução mínima de 30% no volume das tasks principais;
- shell restrito aos casos que o agente não alcança, com chamador nomeado para
  cada script (ADR-0021);
- zero menu de elicitação no fluxo padrão;
- todas as tasks com rota, owner e propósito atuais;
- retomada autônoma sem duplicação ou perda de estado.

## Specs sugeridas

1. `stabilize-toolkit-contracts`
2. `deterministic-pipeline-state`
3. `remove-legacy-bmad-workflows`
4. `adaptive-agent-workflows`
5. `structured-autonomous-runner`
6. `toolkit-evaluation-suite`

## Ordem de decisão

A prioridade é:

```text
confiabilidade → remoção de legado → objetividade → inteligência → autonomia
```

Ampliar a autonomia antes de fechar estado, evidências, contratos e recuperação
fará o toolkit errar mais rápido.

> **Emenda (ADR-0021):** a ordem continua certa; o que mudou é onde a
> confiabilidade mora. Confiabilidade é fato declarado num lugar único mais uma
> verificação com chamador nomeado — não código de shell reimplementando a
> regra. Verificação que ninguém invoca não conta como confiabilidade, com
> qualquer mecanismo. A remoção da gordura herdada não é uma etapa
cosmética: ela reduz ambiguidade, contexto, divergência e custo de manutenção,
criando o espaço necessário para o MOSK tomar decisões melhores.

## Próximo passo

**Etapa 5 — avaliação contínua.** As Etapas 1 a 4 estão entregues ou
substituídas; a 5 é a única que nunca foi atacada e a única cujo valor cresceu
com a virada do ADR-0021.

## Histórico deste documento

- **2026-08-15** — redigido. Diagnóstico e roadmap em cinco etapas.
- **2026-08-20** — Etapas 2 e 4 substituídas pelo ADR-0021 (spec 016). O
  diagnóstico original permanece: ele identificou corretamente que as garantias
  não estavam aplicadas. O que a revisão corrigiu foi a conclusão de que
  aplicá-las exigia codificá-las em shell.
