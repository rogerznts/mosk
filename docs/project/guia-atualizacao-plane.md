# Guia — Como atualizar o projeto no Plane

Guia operacional de como manter as **tarefas do projeto MOSK Toolkit SDD**
no Plane (ferramenta de gestão), espelhando o planejamento de
[`plan.md`](./plan.md) e das tarefas em [`epics/`](./epics/).

> Linguagem das tarefas no Plane: **negócio / pt-BR** (mesma de `epics/`).
> O detalhamento técnico fica nas specs do repositório, não no Plane.

---

## 1. Onde tudo vive

- **Plane:** https://plane.derlo.com.br
- **Workspace:** `ballroom`
- **Projeto:** **Corporativo** (identificador `CORPO`)
- **Item-pai do projeto:** **CORPO-776 — "P2.4 - MOSK Toolkit SDD"**
- **Tarefas filhas (sub-work items):** uma por épico, ligadas ao pai
  CORPO-776. Mapa atual (reconstruído do histórico Git em 6 épicos
  consolidados):

| Épico (em `epics/`) | Plane |
|---|---|
| 01 — Fundação do toolkit & distribuição (degit) | CORPO-1254 |
| 02 — Agentes, skills & menus (rebrand MOSK) | CORPO-1255 |
| 03 — Pipeline SpecKit, papéis & bootstrap de contexto | CORPO-1256 |
| 04 — Integrações: Codex, taste system & rastreabilidade E2E | CORPO-1257 |
| 05 — Estrutura docs v2, sync agente-skill, rules & auditoria | CORPO-1258 |
| 06 — Framework modular, planejamento, handoff & manutenção | CORPO-1259 |

---

## 2. Convenções de preenchimento (o padrão do projeto)

Toda tarefa filha recebe, no mínimo:

- **Responsável:** Roger.Santos.
- **Ciclo:** **2026-1** (janela real: **01/jan → 30/jun/2026**) — o mesmo
  ciclo do item-pai CORPO-776.
- **Label:** **Tecnologia**.
- **Descrição:** três seções — **Resumo · Planejamento · Entregável** —
  derivadas do md do épico em [`epics/NN-*.md`](./epics/). Esse é o
  **Tripé de Definição** exigido pelo manual PMO
  ([`../discovery/project-manual.md`](../discovery/project-manual.md)).
- **Evidência (Protocolo Nexus):** itens em **Done** carregam link/commits
  do repositório `rogerznts/mosk` na descrição (seção *Evidência*).
- **Estado**, **datas** e **estimativa** conforme as regras abaixo.

**Estado (mapeado do status do épico):**

| Status no `plan.md`/`epics` | Estado no Plane |
|---|---|
| Concluído | Done |
| Em andamento | In Progress |
| Aguardando definição | Todo |
| Planejado / Parcial | Backlog |

> Na reconstrução atual, os 6 épicos são histórico já entregue → todos em
> **Done**. Caso o épico 06 passe a refletir evolução ativa, promova-o a
> **In Progress**.

**Estimativa — escala Fibonacci** (a escala "Points" do projeto: 1·2·3·5·8·13).
Regra usada, pelo volume de commits agrupados no épico:

- ≤ 13 commits → **5**
- 14–19 commits → **8**
- ≥ 20 commits → **13**
- Ajustar **para baixo** se houver escopo diferido.

**Datas:** ordem de dependência + janela real de execução (do Git). Itens
concluídos mantêm as **datas reais**, mesmo que anteriores ao início do
ciclo — o próprio CORPO-776 faz isso (datas nov/2025 no ciclo 2026-1), e o
épico 01 também (nov/2025).

**Não preenchidos por padrão** (preencher só se solicitado): **Prioridade**
e **Módulo** (o pai está no módulo "2 - Governança de Dados").

---

## 3. Como atualizar pela interface (UI)

Para **uma tarefa** (o mais comum no dia a dia):

1. Abra a tarefa (ex.: `https://plane.derlo.com.br/ballroom/browse/CORPO-1256/`).
2. No painel **Properties** (direita), clique no campo e escolha o valor:
   **State**, **Assignees**, **Labels**, **Start date**, **Due date**,
   **Cycle**, **Estimate**.
3. A **descrição** é editada no corpo (suporta títulos, listas, negrito).
4. As mudanças salvam sozinhas.

Para **criar uma nova tarefa filha**:

1. Abra o pai **CORPO-776**, role até **"Add sub-work item" → "Create new"**.
2. O modal já vem com o pai vinculado (vira sub-work item). Preencha
   título, descrição e os campos do rodapé (State, Assignees, Labels,
   Start/Due date, Cycle, Estimate).
3. Use o toggle **"Create more"** para criar várias em sequência.

> Para 1–2 itens, a UI é o caminho. Para muitos itens × muitos campos,
> use o método da §4 (bem mais rápido e sem erro de clique).

---

## 4. Como criar/atualizar em massa (API da sessão)

Método usado para criar as tarefas de uma vez. Roda a partir do
**console do navegador já logado no Plane** (mesma origem → usa os cookies
da sessão; **não precisa de token**). É a mesma escrita que a UI faz.

> **Importante:** logo após criar/alterar, a UI pode mostrar valores
> **defasados** (ex.: "No cycle", sem label, sem estimate). **Recarregue
> a página (F5)** — a API é a fonte da verdade. Confirmamos via API que
> os campos ficam corretos mesmo quando a UI ainda não atualizou.

### 4.1 Endpoints (base `/api/workspaces/ballroom/`)

| Ação | Método e caminho |
|---|---|
| Listar projetos | `GET projects/` |
| Estados do projeto | `GET projects/{P}/states/` |
| Escala de estimativa | `GET projects/{P}/estimates/` |
| Ciclos | `GET projects/{P}/cycles/` |
| **Labels do projeto** | `GET projects/{P}/issue-labels/` (também há `GET labels/` no workspace) |
| Membros com nome | `GET members/` |
| **Achar item pelo identificador** | `GET work-items/CORPO-776/?expand=parent` → resolve direto pelo `CORPO-NNN` |
| Detalhe do item (por UUID) | `GET projects/{P}/issues/{ISSUE}/` |
| Sub-itens de um pai | `GET projects/{P}/issues/{PARENT}/sub-issues/` → `.sub_issues[]` |
| **Criar item** (sub-item se enviar `parent_id`) | `POST projects/{P}/issues/` |
| **Atualizar item** | `PATCH projects/{P}/issues/{ISSUE}/` |
| **Pôr no ciclo** | `POST projects/{P}/cycles/{CYCLE}/cycle-issues/` body `{issues:[ID]}` |
| Comentários do item | `GET`/`POST projects/{P}/issues/{ISSUE}/comments/` body `{comment_html}` |

> **Atenção:** o query param `?sequence_id=776` **não filtra** (retorna o
> primeiro item qualquer). Para achar pelo número, use
> `GET work-items/CORPO-776/`.

### 4.2 Campos do item (nomes de escrita / leitura)

- **Escrita** (POST/PATCH): `name`, `description_html` (HTML: `<h2>`,
  `<p>`, `<ul><li>`), `state_id`, `parent_id`, `assignee_ids: []`,
  `label_ids: []`, `start_date`/`target_date` → `"AAAA-MM-DD"`,
  `estimate_point` → **UUID do ponto** (não o número), `priority`
  (opcional): `urgent | high | medium | low | none`.
- **Leitura:** o detalhe (`projects/{P}/issues/{ISSUE}/` e
  `work-items/{IDENTIFIER}/`) devolve o estado em **`state_id`** (não
  `state`), e listas em `assignee_ids` / `label_ids` / `module_ids`,
  parent em `parent_id`, ciclo em `cycle_id`. Verifique por esses nomes.
- **Ciclo não vai no create/patch** → use o endpoint `cycle-issues`.

### 4.3 Exemplo — criar uma tarefa filha

```js
const P='f2a64d9f-2a8b-4cbb-a25b-7e47a6346166';        // projeto Corporativo
const PARENT='530ebf39-a21f-4042-8461-c238b68469a6';   // CORPO-776 (MOSK)
const CYCLE='e22770a1-21f7-4631-a1cd-6111a0d5a25b';    // 2026-1
const ROGER='5cf03cab-6a1c-49c1-952a-b2782d3c86c6';
const TEC='ddaeb280-fc64-42ce-8cc3-7fde4fadc838';
const DONE='e5547668-a423-4a4a-8871-208c066f4602';
const P5='3a241773-d188-4639-95ab-2c430e64b4cb';       // estimativa 5

const payload = {
  name: '01 — Fundação do toolkit & distribuição (degit)',
  description_html: '<h2>Resumo</h2><p>…</p><h2>Planejamento</h2><ul><li>…</li></ul><h2>Entregável</h2><p>…</p>',
  state_id: DONE, parent_id: PARENT,
  assignee_ids: [ROGER], label_ids: [TEC],
  start_date: '2025-11-05', target_date: '2025-11-07',
  estimate_point: P5,
};

const r = await fetch(`/api/workspaces/ballroom/projects/${P}/issues/`, {
  method:'POST', credentials:'include',
  headers:{'content-type':'application/json', accept:'application/json'},
  body: JSON.stringify(payload),
});
const issue = await r.json();                          // issue.id, issue.sequence_id

// pôr no ciclo 2026-1 (passo separado):
await fetch(`/api/workspaces/ballroom/projects/${P}/cycles/${CYCLE}/cycle-issues/`, {
  method:'POST', credentials:'include',
  headers:{'content-type':'application/json', accept:'application/json'},
  body: JSON.stringify({ issues:[issue.id] }),
});
```

> **Idempotência:** antes de criar, liste `…/sub-issues/` e case pelo
> prefixo do nome (`^\d{2} `); se já existir, faça `PATCH` em vez de `POST`
> (evita duplicar épicos numa nova execução).

### 4.4 Exemplo — atualizar um campo (PATCH)

```js
// muda o estado da CORPO-1259 para "In Progress" (precisa do ISSUE id, ver §5)
await fetch(`/api/workspaces/ballroom/projects/${P}/issues/${ISSUE}/`, {
  method:'PATCH', credentials:'include',
  headers:{'content-type':'application/json', accept:'application/json'},
  body: JSON.stringify({ state_id:'d885c87b-2c12-41ac-b29d-7b580850cff4' }),
});
```

### 4.5 Exemplo — comentar no projeto (CORPO-776)

```js
await fetch(`/api/workspaces/ballroom/projects/${P}/issues/${PARENT}/comments/`, {
  method:'POST', credentials:'include',
  headers:{'content-type':'application/json', accept:'application/json'},
  body: JSON.stringify({ comment_html: '<p>Atualização de planejamento…</p>' }),
});
```

---

## 5. Tabela de IDs (referência)

> IDs estáveis do workspace `ballroom`. Se algum mudar, redescubra com os
> `GET` da §4.1.

**Base**

| Item | ID |
|---|---|
| Projeto Corporativo (`CORPO`) | `f2a64d9f-2a8b-4cbb-a25b-7e47a6346166` |
| Item-pai CORPO-776 (MOSK Toolkit SDD) | `530ebf39-a21f-4042-8461-c238b68469a6` |
| Responsável Roger.Santos | `5cf03cab-6a1c-49c1-952a-b2782d3c86c6` |
| Label **Tecnologia** | `ddaeb280-fc64-42ce-8cc3-7fde4fadc838` |
| Label **G** (também no pai) | `a21868fa-50ec-48b2-883d-0b5c3e8ba018` |

**Sub-itens (épicos)**

| Épico | CORPO | UUID |
|---|---|---|
| 01 | CORPO-1254 | `4f38a36f-a776-493b-a279-c62295a1e3e7` |
| 02 | CORPO-1255 | `25b3adf1-3773-440b-95d6-135ef9568c86` |
| 03 | CORPO-1256 | `018e507b-d160-4d45-9144-6e6c6dd77e9e` |
| 04 | CORPO-1257 | `ca835ba2-79e4-4db5-bd91-62a46fc2954c` |
| 05 | CORPO-1258 | `f36c7fa2-af6b-4595-9c08-4c9833b83ac0` |
| 06 | CORPO-1259 | `c1ef7c2e-5f06-4528-91e9-65d7dcac35d7` |

**Estados**

| Estado | ID |
|---|---|
| Backlog | `5d42a697-09da-414e-9d4a-6dc2895c815b` |
| Todo | `02cbde64-bfa3-4375-9b6e-485fb7300558` |
| In Progress | `d885c87b-2c12-41ac-b29d-7b580850cff4` |
| Done | `e5547668-a423-4a4a-8871-208c066f4602` |
| Cancelled | `5f9cb021-b20a-43aa-9264-7fad490eb883` |

**Estimativa (escala "Points" = Fibonacci)**

| Valor | ID do ponto |
|---|---|
| 1 | `c27f3f2e-32ff-4c8b-863d-9d61eb1d8bbe` |
| 2 | `c2d8dfdf-a052-4ffe-a687-9883ec4218d2` |
| 3 | `2d672c35-5743-48ab-9e03-0ed08e96f1d9` |
| 5 | `3a241773-d188-4639-95ab-2c430e64b4cb` |
| 8 | `6e83ae8c-9942-4367-bf1c-2faed7da5883` |
| 13 | `dbf4e68a-4cfb-4f66-a4cb-fd4175a1e8d0` |

**Ciclos**

| Ciclo | Janela | ID |
|---|---|---|
| 2025-1 | 16/abr → 30/jun/2025 | `64277310-41fb-4bd4-98a6-f9fb4f2eb059` |
| 2025-2 | 01/jul → 31/dez/2025 | `334c7fa8-f110-4b61-9232-695521576d0a` |
| **2026-1** | **01/jan → 30/jun/2026** | `e22770a1-21f7-4631-a1cd-6111a0d5a25b` |
| 2026-2 | 01/jul → 31/dez/2026 | `e9bdb64b-77aa-428e-9a63-26625133e214` |
| 2027-1 | 01/jan → 30/jun/2027 | `ae6f36b8-689e-4231-8b6f-17c4b6af0327` |

---

## 6. Cuidados

- **Cache da UI:** recarregue após criar/alterar antes de concluir que
  "não funcionou" (ver §4).
- **`state_id`, não `state`:** ao ler o detalhe para conferir o estado, o
  campo é `state_id`. O mesmo vale para `assignee_ids`/`label_ids`/`cycle_id`.
- **Achar por número:** use `GET work-items/CORPO-NNN/`; o `?sequence_id=`
  **não** filtra.
- **Labels são de workspace**, mas há o endpoint por projeto
  (`projects/{P}/issue-labels/`). Há labels de nome curto repetido (ex.:
  "G"); use o **ID** correto.
- **Estimativa e label são referenciadas por UUID**, nunca pelo número/nome.
- **Ciclo é passo separado** (`cycle-issues`), não vai no create/patch.
- Rode os scripts **na aba logada do Plane** (mesma origem); a sessão do
  navegador é a autenticação.
- Mantenha o Plane **alinhado ao `plan.md`/`epics`**: ao mudar status,
  datas ou escopo no planejamento, reflita na tarefa correspondente
  (rode `/mosk-pm planner` na cadência).
