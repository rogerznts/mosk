# Feature Specification: Hallmark como ferramenta do `mosk-ui-expert`

**Feature Branch**: `008-feature-ui-expert-hallmark`
**Created**: 2026-07-26
**Status**: Implemented
**Input**: User description: "utilize a skill hallmark e vamos criar ela como ferramenta para o mosk-ui-expert; copie a pasta de references e adeque também para a estrutura do mosk/.claude/mosk"

## Contexto

O Tiago (`mosk-ui-expert`) tinha seis tasks `webdesign-*.md` cobrindo *acabamento
visual*: três estilos fixos (brutalist / minimalist / soft), uma auditoria de
redesign, um gerador de `DESIGN.md` para Stitch e um enforcement de output. Nenhuma
delas ataca **variedade estrutural** — duas páginas geradas para briefs diferentes
convergem para o mesmo ritmo hero → 3 features → CTA → footer.

O [Hallmark](https://github.com/Nutlope/hallmark) (Nutlope / Together AI, MIT)
codifica exatamente isso: 21 macroestruturas nomeadas, 50 arquétipos de componente,
20 temas com tokens OKLCH, 4 gêneros, 58 gates de slop-test, regra de diversificação
com memória de projeto, e 4 verbos.

## User Scenarios & Testing

### User Story 1 — Rodar o Hallmark pelo Tiago (Priority: P1)

O usuário pede uma página nova e quer que ela não se pareça com saída de IA. Ele
escreve `hallmark landing do produto` — com ou sem `/mosk-ui-expert` na frente — e o
fluxo completo roda: pre-flight, pergunta de contexto, escolha declarada de
macroestrutura/tema/nav/footer, preview, build, slop test.

**Why this priority**: é a razão de existir da feature. Sem isso nada mais importa.

**Independent Test**: num projeto de scratch com frontend, invocar e conferir que a
saída traz o bloco de preview com seis bullets, o stamp CSS
`/* Hallmark · macrostructure: … */` e um `tokens.css`.

**Acceptance Scenarios**:

1. **Given** uma sessão sem agente ativo, **When** o usuário escreve `hallmark audit
   src/App.tsx`, **Then** a skill `mosk-ui-expert` é roteada pela description e o
   verbo `audit` roda, devolvendo punch list sem editar arquivo nenhum.
2. **Given** `/mosk-ui-expert`, **When** o usuário escolhe o item 8 do menu, **Then**
   entra no fluxo Hallmark.
3. **Given** o usuário escreve `redesign src/App.tsx` (verbo nu, sem prefixo),
   **When** o Tiago recebe, **Then** ele faz **uma** pergunta de desambiguação entre
   Hallmark e o `webdesign-redesign` clássico antes de rotear.

### User Story 2 — Artefatos no lugar certo do layout MOSK (Priority: P2)

O Hallmark é agnóstico de projeto: escreve `design.md` e artefatos na raiz. Dentro do
MOSK, documentos de design pertencem a `docs/ui/` — ou a `docs/specs/{id}/ui/` com
`promote:` quando há spec ativa.

**Why this priority**: sem isso o Hallmark polui a raiz e quebra o contrato de
promoção do MOSK.

**Independent Test**: rodar o fluxo dentro de uma spec ativa e verificar que o
artefato caiu em `docs/specs/{id}/ui/` com front-matter `promote:`.

**Acceptance Scenarios**:

1. **Given** um projeto sem spec ativa, **When** o Hallmark emite um design system,
   **Then** o arquivo é `docs/ui/design-system.md`, não `design.md` na raiz.
2. **Given** um projeto com `.claude/rules/frontend.md`, **When** o pre-flight roda,
   **Then** as regras são lidas antes de `package.json` e citadas no bloco de
   achados.

### User Story 3 — Vendor atualizável (Priority: P3)

O Hallmark é upstream vivo. O vendor precisa ser atualizável sem perder as adequações
MOSK.

**Why this priority**: sem isso o fork apodrece e a próxima atualização apaga a
integração — o modo de falha clássico de vendoring.

**Independent Test**: `sync-hallmark.sh --dry-run` fecha limpo (round-trip
idempotente); `--ref <sha-antigo>` conflita, gera `.rej` e **não** troca o vendor.

**Acceptance Scenarios**:

1. **Given** o vendor no ref pinado, **When** roda `sync-hallmark.sh --dry-run`,
   **Then** o diff contra o vendor atual é vazio.
2. **Given** um ref cujo upstream mudou o texto adaptado, **When** roda o sync,
   **Then** aborta com `.rej` preservados e o vendor intacto.

### User Story 4 — Sync de skills que não destrói nada (Priority: P1, adjacente)

Precisar de uma description com gatilhos expôs um bug latente: o
`sync-agents-skills.sh` derivava a description da primeira linha da `## Mission`
(`head -1`) e regenerava o `SKILL.md` inteiro a partir do boilerplate. Num projeto
consumidor, **uma** execução trocava as 11 descriptions curadas do template por
prosa em inglês truncada e apagava o `argument-hint:` e o corpo autoral do
`mosk-orq` — sem nenhum erro.

**Why this priority**: a feature depende de uma description estável para o
roteamento por linguagem natural. Entregar o Hallmark sobre um mecanismo que se
autodestrói seria entregar pela metade.

**Independent Test**: instalar o template num diretório limpo, rodar
`sync-agents-skills.sh both` e comparar todas as descriptions com as do template.

**Acceptance Scenarios**:

1. **Given** um consumidor recém-instalado, **When** roda `sync-agents-skills.sh
   both`, **Then** nenhuma das 12 descriptions diverge do template e o
   `argument-hint:` do `mosk-orq` continua lá.
2. **Given** um agente com `<!-- skill-description: … -->`, **When** a `## Mission`
   é reencapada, **Then** a description não muda.
3. **Given** duas execuções seguidas do sync, **When** a segunda roda, **Then**
   reporta `Updated: 0`.

### Edge Cases

- **Verbo nu ambíguo** (`redesign X`, `audit X`) → pergunta de uma linha, nunca
  escolha silenciosa.
- **Upstream reescreve um trecho adaptado** → o replay do diff conflita; o script
  falha alto em vez de aplicar pela metade.
- **`.claude/rules/` ausente** → o pre-flight avisa em uma linha e segue com as seis
  fontes originais.
- **Conflito de baseline** (Tiago bane serif e `Inter`; o Hallmark usa serifas de
  display em seis temas e Inter Tight em `modern-minimal`) → precedência explícita:
  enquanto a task está carregada, o Hallmark vence.

## Requirements

### Functional Requirements

- **FR-001**: O template MUST embarcar o corpo do Hallmark em
  `mosk/.claude/mosk/data/hallmark/`, seguindo o precedente de `data/` como material
  de referência estático lido por tasks.
- **FR-002**: Uma task MUST expor os quatro verbos ao Tiago via uma linha em
  `## Task mapping`, com disciplina de carregamento progressivo explicitada.
- **FR-003**: As seis tasks `webdesign-*` MUST continuar funcionando sem alteração de
  comportamento.
- **FR-004**: O sistema MUST rotear `hallmark <verbo>` escrito cru, sem slash, para o
  `mosk-ui-expert`.
- **FR-005**: Documentos de design MUST respeitar o layout MOSK (`docs/ui/` ou
  `docs/specs/{id}/ui/` com `promote:`).
- **FR-006**: O vendor MUST preservar `LICENSE` (MIT) e declarar origem, ref pinado e
  modificações em `VENDOR.md`.
- **FR-007**: Um script MUST re-sincronizar o vendor preservando as adequações MOSK,
  abortando sem tocar no vendor quando houver conflito.
- **FR-008**: O `mosk-ui-expert` MUST declarar que as regras do Hallmark vencem a
  `## Core design philosophy` enquanto a task estiver carregada.
- **FR-009**: A `description` de uma skill de agente MUST ser declarada no próprio
  agente (`<!-- skill-description: … -->`), separada da `## Mission`.
- **FR-010**: `sync-agents-skills.sh` MUST editar wrappers e CC agents existentes no
  lugar — só a linha `description:` — preservando front-matter extra e corpo autoral.

### Key Entities

- **Vendor** (`data/hallmark/`) — 109 arquivos: `hallmark.md` (entry point),
  `references/` (105), `references/themes/tokens.css`, `LICENSE`, `VENDOR.md`.
- **Task roteadora** (`tasks/hallmark.md`) — detecção de verbo, disciplina de
  carregamento, integração MOSK, regras.
- **Blocos preservados** — `MOSK-HEADER` e `MOSK-INTEGRATION`, delimitados por
  comentários HTML, invariantes verificados pelo script de sync.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% dos links markdown internos do vendor resolvem (268 links, 0
  quebrados).
- **SC-002**: `sync-hallmark.sh --dry-run` no ref pinado produz diff vazio contra o
  vendor — round-trip idempotente.
- **SC-003**: `sync-agents-skills.sh both --dry-run` reporta `Updated: 0` nos dois
  trees, e num consumidor recém-instalado o sync deixa **0** descriptions
  divergentes (antes da correção: 10) preservando o `argument-hint:` do `mosk-orq`.
- **SC-004**: `hallmark`, `hallmark audit`, `hallmark redesign` e `hallmark study`
  alcançam o Tiago a partir das quatro formas de invocação documentadas.
- **SC-005**: Nenhuma das seis tasks `webdesign-*` muda de conteúdo.

---
**Arquivado em:** 2026-07-26
**Status final:** Concluído
**Promoções aplicadas:** 1 `copy` (ADR-0011 → `docs/architecture/adr/`) · 0 `append` · 0 `manual`
