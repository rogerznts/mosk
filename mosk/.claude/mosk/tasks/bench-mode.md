# bench-mode

Orquestra o modo `/mosk-bench` (persona Bento) de ponta a ponta: leva um usuário
**leigo** de "quero uma ferramenta interna" a "ferramenta rodando e testada no
navegador", **sem nenhuma decisão técnica exposta**.

O bench é **stack-agnóstico**: o fluxo abaixo é genérico e delega tudo que é
específico da tecnologia a um **adapter da stack ativa**. Hoje existe um único
adapter — **Payload** — que é o default. Adicionar uma stack no futuro é criar um
novo adapter (`<stack>-starter/` + `<stack>-*.sh` + `<stack>-rule-tmpl.md` + entrada
na tabela do adapter), **sem** renomear o bench nem reescrever este fluxo.

## User Input

```text
$ARGUMENTS
```

## Goal

Executar a espinha dorsal do modo, resolvendo tudo que é técnico por **convenção
determinística** (scripts do adapter + starter versionado) ou **headless** (Fase B),
e falando com o usuário **sempre em pt-BR simples** (INV-6).

```
ativar → validar ambiente → provisionar infra → criar/reconhecer projeto →
grill (Fase A) → congelar briefing → derivar testes → build headless (Fase B) → entregar
```

---

## Adapter da stack ativa

O fluxo genérico resolve cada capacidade específica de stack pelo adapter. **Stack
ativa (default): `payload`.** Mapa do adapter Payload:

| Capacidade (genérica)         | Adapter Payload (concreto)                                   |
|-------------------------------|-------------------------------------------------------------|
| Starter versionado            | `.claude/mosk/templates/payload-starter/`                   |
| Validação de ambiente         | `.claude/mosk/scripts/payload-env.sh`                       |
| Infra + provisionamento       | `.claude/mosk/scripts/payload-infra.sh`                     |
| Template da rule de contexto  | `.claude/mosk/templates/payload-rule-tmpl.md`              |
| Rule de contexto gerada       | `.claude/rules/payload.md`                                  |
| Comando de teste (no container)| `docker compose exec app pnpm test` (Vitest, Local API)   |
| Deploy / publicação†          | `.claude/mosk/scripts/payload-deploy.sh` (Railway)         |
| Termo de "módulo"             | collection do Payload                                       |
| Invariantes da stack          | INV-1..6 (ver abaixo)                                       |

> Onde este documento disser "o adapter", leia a linha correspondente na tabela.
> Toda a lógica de fases da Fase B (SDD) é **genérica** e não depende da stack.
>
> † **Deploy é uma skill SEPARADA e opt-in (`/mosk-deploy`), não uma fase deste
> fluxo.** O bench entrega sempre em `http://localhost:<porta>` (dev) e não faz
> deploy. A publicação em produção é conduzida pela task `deploy-mode.md` — o build
> roda remoto no provedor, então INV-4 permanece válida (ver ADR-0005).

### Invariantes da stack Payload (contrato — nunca violar)

- INV-1 admin pt-BR + menu completo · INV-2 módulo = collection · INV-3 Postgres+Redis ·
  INV-4 zero build local (só Docker) · INV-5 usuário decide só regra de negócio ·
  INV-6 saída sempre pt-BR simples.
- Bifurcação técnica ⇒ **default seguro + aviso**, nunca pergunta (FR-014).
- Nenhum YAML/porta/nome de container/comando aparece ao usuário no fluxo normal (SC-006).

---

## Fase 0 — Ativação e contexto

1. Leia todos os `.claude/rules/*.md` (inclusive a rule de contexto do adapter —
   hoje `payload.md` — se existir; FR-002/033).
2. Se `$ARGUMENTS` traz o desejo do usuário, use como ponto de partida; senão, dê
   boas-vindas em pt-BR e pergunte, em uma frase, que ferramenta ele quer.

---

## Fase 1 — Validar ambiente (determinístico)

Execute o **script de ambiente do adapter** (`payload-env.sh`):
`bash .claude/mosk/scripts/payload-env.sh`.

- Valida Docker na ordem `docker --version → docker info → docker compose version`
  (FR-003) e, faltando Docker, conduz a instalação guiada com **uma confirmação**
  (FR-004, US3).
- Você (Bento) traduz para pt-BR humano: "Vou preparar o ambiente..."; se o script
  pedir confirmação de instalação, repasse em linguagem simples e **espere o 'sim'**.
  Recusa ⇒ pare com instrução amigável (FR-004).
- Saída != 0 ⇒ não avance. Explique em pt-BR o que faltou.

---

## Fase 2 — Provisionar infra compartilhada (determinístico)

Use o **script de infra do adapter** (`payload-infra.sh`):

1. `bash .claude/mosk/scripts/payload-infra.sh` — detecta/cria/reusa a infra
   compartilhada (`mosk-net` + Postgres + Redis) de forma idempotente e aplica o
   health gate (FR-005/006, ADR-0001). Na primeira vez, avise: "Estou ligando os
   serviços pela primeira vez, isso pode demorar um pouco."
2. Provisione a alocação do projeto:
   `bash .claude/mosk/scripts/payload-infra.sh --provision "<nome-do-projeto>"`
   — devolve, no bloco `ALLOC_*`, o banco, a porta do admin e o índice/prefixo Redis
   (FR-007/008). Guarde esses valores para o `.env` e para a rule de contexto.
   - Projeto já provisionado ⇒ o script **reusa** a alocação (não reprovisiona) — US2.

Nunca mostre porta/banco/índice ao usuário; são convenção interna.

---

## Fase 3 — Projeto novo vs. bootstrap existente

Decida a partir do diretório atual / `$ARGUMENTS`:

- **Existe** um projeto criado pelo bench aqui (starter do adapter presente +
  rule de contexto `.claude/rules/payload.md`)? ⇒ **bootstrap detectado**: pule o
  scaffold e vá para o ciclo aditivo (US2 — ver `## Fase 6` / T021–T022).
  *(US2 não faz parte desta rodada de MVP.)*
- **Não existe** ⇒ siga o **scaffold de projeto novo** abaixo (T016, US1).

### 3a — Scaffold de projeto novo (T016, determinístico)

1. Copie o **starter do adapter** (`payload-starter/`) **as-is** para
   `~/projects/<nome>` (FR-009/034). Não gere nada on-the-fly (ADR-0003).
2. `git init` no projeto novo.
3. Gere o `.env` a partir do `.env.example` do starter, preenchendo com o bloco
   `ALLOC_*` da Fase 2: `DATABASE_URI`, `REDIS_URL` (com índice ou prefixo),
   `ADMIN_PORT`, e um `PAYLOAD_SECRET` aleatório recém-gerado.
4. Gere a rule de contexto (`.claude/rules/payload.md`) a partir do template do
   adapter (`payload-rule-tmpl.md`), preenchendo alocação + (mais adiante) o resumo
   do briefing (FR-036).
5. O LLM **só** customizará a camada de módulos do starter (para Payload:
   `src/collections/` e labels) — nunca o compose, a infra ou a base da config
   (FR-011).

---

## Fase A — Grill interativo (LLM, humano nas respostas)

Invoque `.claude/mosk/tasks/grill.md` com um **checklist obrigatório** de completude.
Regras específicas do modo (sobrepõem o grill genérico):

- Uma pergunta por vez, **só sobre regra de negócio/domínio**, em pt-BR simples (FR-013).
- Toda bifurcação técnica ⇒ **default seguro + aviso**, nunca pergunta (FR-014).
- **Traduza** o vocabulário técnico do checklist para linguagem do usuário:
  módulos (collections) → "cadastros/módulos"; campos → "informações"; papéis →
  "quem pode usar"; integrações → "conexões prontas"; regra de negócio → "regras";
  "pronto" → "quando você considera a ferramenta pronta".

**Checklist obrigatório (todos os itens precisam ser resolvidos — FR-015):**

- [ ] Módulos + campos de cada um.
- [ ] Papéis/permissões (quem pode ver/editar o quê).
- [ ] Integrações "de fábrica" necessárias.
- [ ] Labels em pt-BR de cada módulo/campo.
- [ ] Regras de negócio (validações, automações, estados).
- [ ] Critério de "pronto" (o que precisa funcionar para o usuário aceitar).

Convergência **só** com checklist 100% (FR-015). Escape manual **"chega"** congela o
briefing com o que houver, **registrando as lacunas** (FR-016).

---

## Congelar briefing + derivar testes (determinístico + LLM nos asserts)

Ao convergir (ou no escape):

1. Grave, na pasta do projeto, o **briefing congelado**:
   - `briefing.md` — o combinado em pt-BR (inclui lacunas, se houver).
   - `checklist.yaml` — o checklist resolvido, item a item.
   (FR-017)
2. Atualize a rule de contexto (`.claude/rules/payload.md`) com o resumo do briefing.
3. **Derive os testes a partir do checklist** — simetria: o checklist **é** a
   especificação dos testes (FR-018). Camadas:
   - **base/smoke**: herdada do starter, não reescrever.
   - **por módulo** (estrutura template): existe? campos corretos? CRUD? papéis?
   - **regras de negócio**: asserts redigidos pelo LLM a partir do checklist.
   Rodam via o **comando de teste do adapter** (`docker compose exec app pnpm test`,
   Vitest via Local API — sem HTTP, sem browser) (FR-019).

---

## Fase B — Build autônomo headless (RAPC — ADR-0004)

A Fase B roda o build **fora da vista do leigo**. É uma **máquina de estados de fases
discretas, idêntica nos dois runtimes**, cuja **única fonte da verdade é o disco**
(diretório da spec + `spec-meta.yaml.current_phase` + artefatos + `decisions-log.md`).
Esta orquestração é **genérica** (não depende da stack).

```
specify → plan → tasks → build-loop → qa-gate → deliver
```

### Contrato de cada fase (runtime-agnostic)

- **Pré-condição:** ler os artefatos exigidos do `spec_dir`.
- **Ação:** executar o trabalho (script determinístico ou passo LLM/subagente).
- **Pós-condição:** escrever artefatos, atualizar `spec-meta.yaml.current_phase`
  (via `update_spec_phase` do `common.sh`) e fazer **append** em `decisions-log.md`
  quando houve auto-escalação (ADR-0002).

Tudo que **determina a saída** (sequência de fases, loop, teto 3, `decisions-log.md`,
`gate.yaml`, entrega pt-BR, "zero decisão técnica exposta") é **idêntico** nos dois runtimes.

### O único ponto runtime-específico: seam `invoke_phase_agent(role, phase, spec_dir)`

Todo passo que precisa de um agente MOSK (`po`/`dev`/`qa`, e destes para `architect`/`pm`)
passa por **um único adaptador**. Dois tiers (ADR-0004):

- **Tier 1 — isolamento estrutural (preferido; Claude Code):** lance a tool nativa de
  subagente (`Agent`, `subagent_type: mosk-<role>`). Entrada = caminho do `spec_dir` + a
  fase; a instrução manda o subagente **ler/escrever no disco** e **devolver só um status
  curto**. O barulho de build **fisicamente não entra** no contexto do Bento.
- **Tier 2 — isolamento lógico (Codex default):** rode a **mesma** task de fase na sessão,
  sob **disciplina de supressão de output** — nada de streaming de tool-output/raciocínio
  verboso ao usuário; o log verboso é **redirecionado para `build-log.md`** no `spec_dir`
  (auditável, nunca exibido). O disco continua sendo a fronteira de estado.
- **Tier 1' (opcional, Codex):** onde `codex exec` (não-interativo) existir, cada fase pode
  virar **processo filho headless** com stdout capturado em `build-log.md`. É reforço, não
  requisito de paridade.

> `build-log.md` é **efêmero** (o `.gitignore` do starter já o ignora); `decisions-log.md`
> é **auditável e versionado**.

### Sequência de fases

1. **specify** — `bash .claude/mosk/scripts/create-new-feature.sh` (numeração/branch/
   `spec-meta` atômicos). Projeto novo ⇒ spec **001**; reativação ⇒ spec **aditiva N** (FR-021).
2. **plan** — `invoke_phase_agent(po, plan, spec_dir)` (task `plan.md`).
3. **tasks** — `invoke_phase_agent(po, tasks, spec_dir)` (task `tasks.md`).
4. **build-loop** — por tarefa: `invoke_phase_agent(dev, implement, spec_dir)`
   (task `implement.md`) → roda os testes (comando de teste do adapter) → compara.
   - "**Verde**" = smoke + testes por módulo + asserts de regra, todos passando (FR-023).
   - Não passou ⇒ conserta e repete, com **teto `MAX_FIX_ATTEMPTS=3`** por tarefa
     (configurável via env, **nunca** perguntado ao leigo). Estourou ⇒ registra falha
     persistente e marca gate `CONCERNS` (FR-022). Loop **nunca** é infinito (SC-004).
   - **Auto-escalação escopada (ADR-0002):** dentro deste loop, `dev` pode invocar
     `architect`/`pm` **automaticamente** para resolver questão **técnica**, por default
     seguro, **registrando** a decisão em `decisions-log.md` — sem pausar o leigo.
   - **Limite duro:** lacuna de **regra de negócio** ausente no briefing **não** é
     inventada (FR-026): o build para, registra a lacuna, e devolve ao grill (Fase A) ou
     entrega com gate `CONCERNS` explicando em pt-BR.
5. **qa-gate** — `invoke_phase_agent(qa, qa-gate, spec_dir)` (task `qa-gate.md`) ⇒
   `gate.yaml` (`PASS`/`CONCERNS`/`FAIL`) na pasta da spec (FR-024).
6. **deliver** — ver "Entrega".

### Contrato de apresentação único (idêntico nos dois runtimes)

O que o leigo vê é **sempre**: **uma linha de progresso pt-BR por fase**
(ex.: "Montando a base...", "Ensinando as regras...", "Testando tudo...") + a entrega
final. Todo o resto vai para `build-log.md`/`decisions-log.md`. O transcript visível é
**equivalente** nos dois runtimes; muda só **como** o barulho é mantido longe (FR-030).

---

## Entrega (FR-028/029)

- Gate `PASS` ⇒ entregue em pt-BR: o endereço `http://localhost:<ADMIN_PORT>`, um resumo
  do que foi criado (em linguagem de negócio) e as credenciais de login.
- Gate `CONCERNS`/`FAIL` ⇒ resumo pt-BR, sem jargão, do que ficou pendente e das lacunas
  registradas (FR-029). Nunca despeje log técnico.

---

## Fase 6 — Iteração aditiva (US2 — T021/T022)

Este é o caminho quando a Fase 3 detectou **bootstrap** (projeto do bench já existe
aqui). O leigo volta para pedir uma mudança ("quero também guardar fornecedores",
"o gerente precisa aprovar antes de publicar"). O modo **evolui** a ferramenta, nunca
a reconstrói.

### 6a — Reuso determinístico (sem reprovisionar)

1. **Pula o scaffold** (starter já está no disco).
2. **Reusa infra e alocação**: `bash .claude/mosk/scripts/payload-infra.sh --provision
   <nome-projeto>` é **idempotente** — projeto já registrado no `registry.yaml` é
   reusado sem tocar em banco/porta/índice Redis (FR-012). A ferramenta mantém o
   **mesmo endereço** de sempre.
3. **Carrega o contexto vivo**: leia a rule do adapter (`.claude/rules/payload.md`) e
   as collections existentes (`src/collections/`) para aterrissar o grill no que já
   existe — o leigo não repete o que já foi decidido.

### 6b — Grill só do incremento (Fase A, reduzida)

- Rode a Fase A **apenas sobre o delta**: o checklist de completude cobre só a mudança
  pedida (novos módulos/campos, nova regra, novo papel), não a ferramenta inteira.
- **Desafie contra o que já existe**: se o incremento colide com uma collection/regra
  atual, resolva no grill (renomear? estender? substituir?) antes de congelar.
- Mesmo critério de convergência (checklist verde) e escape manual ("chega").

### 6c — Build aditivo (Fase B, mesmo contrato)

- **specify** cria uma **spec aditiva N** (não a 001) via `create-new-feature.sh`
  (reserva de número atômica; branch + `spec-meta` próprios) — cada incremento é uma
  spec rastreável no git (FR-021).
- **plan → tasks → build-loop → qa-gate → deliver** seguem o **mesmo** contrato da
  Fase B (RAPC), com uma garantia extra:
  - **Preservação**: o LLM só **adiciona/edita** dentro de `src/collections/` e labels
    para atender o delta; **não** remove nem reescreve módulos existentes salvo se o
    incremento explicitamente pedir (e o grill confirmou em 6b).
  - **Regressão**: os testes **acumulam** — o smoke da base + os testes dos módulos
    antigos continuam rodando junto com os do módulo novo. "Verde" exige **tudo**
    passando, então uma mudança que quebre o que já existia falha o gate (não entrega
    silenciosamente uma regressão).
- **deliver**: mesmo endereço `http://localhost:<ADMIN_PORT>`, resumo em pt-BR do que
  **mudou** nesta iteração (linguagem de negócio), sem jargão.

---

## Rules

- Determinismo primeiro: ambiente, infra e scaffold são scripts do adapter + starter
  versionado, nunca geração on-the-fly (ADR-0003).
- O LLM só toca a camada de módulos do starter (Payload: `src/collections/` e labels) (FR-011).
- Estado da Fase B **só** no disco; nada em memória entre fases (ADR-0004).
- Auto-escalação vive **apenas** aqui (Fase B); o contrato global do MOSK segue intocado
  (FR-027, ADR-0002).
- Nunca exponha decisão técnica, jargão, porta, banco ou comando ao usuário (INV-5/6, SC-006).
- Toda menção a Payload neste fluxo é **via adapter**; trocar/adicionar stack não muda
  este roteiro, só a tabela do adapter.
