---
promote: docs/architecture/adr/adr-0004-runtime-agnostic-phase-orchestration.md
promote_mode: copy
---

# ADR-0004 — Orquestração da Fase B: contrato de fases agnóstico de runtime + isolamento como capacidade

- Status: aceito
- Data: 2026-07-19
- Autor: Vinicius (mosk-architect)
- Contexto: modo `/mosk-payload` — ver `../../../../architecture/mosk-payload-mode.md` §5 e `../../plan.md` §Open Architecture Decision.
- Origem: item aberto do `plan` (mecanismo de encadeamento de subagentes headless da Fase B) + FR-030/SC-007 (paridade Claude Code ↔ Codex).
- Depende de: [adr-0002](../../../../architecture/adr/adr-0002-auto-escalation-exception.md) (auto-escalação escopada).

## Contexto

A Fase B do modo `/mosk-payload` roda o build **headless** — o leigo nunca
vê o barulho de build (INV-6, regra de ouro). O `plan` já fixou a base
(pontos 1–5): a própria `payload-mode.md` orquestra; o estado transita por
**filesystem** (diretório da spec + `spec-meta.yaml.current_phase` +
artefatos + `decisions-log.md`); o loop-until-green é determinístico com
teto `MAX_FIX_ATTEMPTS=3`; a auto-escalação é escopada (ADR-0002).

Restou **uma** fronteira que o `plan` não fechou unilateralmente:

- No **Claude Code**, o fan-out `po → dev → qa` usa a tool nativa de
  subagente (`Agent` com `subagent_type`). Isso dá **isolamento real de
  contexto/processo**: o output de ferramentas do subagente não polui o
  contexto pai; só o resultado volta. A propriedade "headless/invisível" é
  **estrutural**.
- No **Codex** **não existe** primitivo de subagente isolado equivalente.
  A propriedade "headless/invisível" **não é nativa** lá.

As duas saídas cruas do `plan` eram: (a) **degradar em Codex** — pipeline
linear na mesma sessão, apenas resumido, sem isolamento real; (b)
**contrato de orquestração agnóstico de runtime** — fases dirigidas por
filesystem/estado que ambos executam igual, tratando o isolamento como
capacidade opcional do runtime.

Isso molda o prompt de `payload-mode.md` e a promessa de paridade
(FR-030), então é difícil de reverter — merece ADR.

## Decisão

Adotar uma **síntese de (b) com (a) como perfil de degradação de um dos
tiers** — **não** (a) puro nem (b) que nivela por baixo.

**1. Contrato de fases agnóstico de runtime (RAPC — Runtime-Agnostic
Phase Contract).** A Fase B é uma máquina de estados de fases discretas,
idêntica nos dois runtimes, cuja **única fonte da verdade é o disco**:

```
specify → plan → tasks → build-loop → qa-gate → deliver
```

Cada fase tem o mesmo formato nos dois runtimes:

- **Pré-condição:** lê os artefatos exigidos do diretório da spec.
- **Ação:** executa o trabalho (script determinístico ou passo
  LLM/subagente).
- **Pós-condição:** escreve artefatos, atualiza
  `spec-meta.yaml.current_phase` (via `update_spec_phase` do `common.sh`),
  e faz append em `decisions-log.md` quando houve auto-escalação (ADR-0002).

Tudo que **determina a saída** — sequência de fases, loop determinístico,
teto 3, conteúdo do `decisions-log.md`, `gate.yaml`, entrega pt-BR, "zero
decisão técnica exposta ao leigo" — é **runtime-agnostic e idêntico**.

**2. Isolamento é uma capacidade do runtime, resolvida por um único
seam.** O único ponto runtime-específico é o adaptador
`invoke_phase_agent(role, phase, spec_dir)`, com **dois tiers**:

- **Tier 1 — isolamento estrutural (preferido; Claude Code):** lança a
  tool nativa de subagente (`subagent_type: mosk-<role>`); entrada = path
  do `spec_dir` + fase; saída = escreve no disco e devolve só um status
  curto. O barulho de build **fisicamente não entra** no contexto pai.
- **Tier 2 — isolamento lógico (Codex default):** roda a **mesma** task de
  fase na sessão, sob **disciplina de supressão de output** — nada de
  streaming de tool-output/raciocínio verboso para o usuário; o log
  verboso é **redirecionado** para `build-log.md` no diretório da spec
  (auditável, não exibido). O disco continua sendo a fronteira de estado.
- **Tier 1' (opcional, Codex):** onde o `codex exec` (modo não-interativo)
  estiver disponível, cada fase pode ser disparada como **processo filho
  headless** capturando stdout em `build-log.md` — recuperando isolamento
  de processo real também no Codex. É **enhancement**, não requisito de
  paridade (evita depender de um engine novo; ver Alternativas).

**3. Contrato de apresentação único (idêntico nos dois runtimes).** Toda
saída visível ao leigo passa pelo **mesmo** contrato: uma linha de
progresso pt-BR por fase + a entrega final (FR-028/029). Todo o resto vai
para `build-log.md`/`decisions-log.md`. Consequência: o **transcript que o
leigo vê é idêntico** nos dois runtimes; o que difere é **como** o barulho
é mantido longe dele — estrutural (Tier 1) vs disciplina+redirecionamento
(Tier 2).

**4. Honestidade da promessa (FR-030).** A paridade é **equivalente para o
usuário** (mesmo transcript, mesma entrega, mesmo resultado, mesmas
invariantes), com o **mecanismo de isolamento tratado como capacidade do
runtime**. A afirmação "de forma idêntica" de FR-030 é **suavizada para
"equivalente"** (alinhando com SC-007, que já dizia "equivalente"), com a
nuance de isolamento registrada. Ver "Ajustes aplicados".

## Alternativas consideradas

1. **(a) puro — degradar sempre para linear-in-session.** Simples, mas
   jogaria fora o isolamento **real** que o Claude Code já oferece de
   graça e poluiria o contexto pai mesmo onde não é preciso. É **nivelar
   por baixo**. Rejeitada.
2. **(b) nivelando por baixo — ambos rodam linear com isolamento só
   lógico.** Contrato agnóstico é bom, mas forçar o Claude Code a abrir mão
   do subagente isolado para "igualar" o Codex é a mesma perda do item 1.
   Rejeitada. A síntese adotada mantém o contrato agnóstico **e** deixa
   cada runtime usar o melhor isolamento que tem.
3. **`codex exec` headless como baseline obrigatório da paridade.**
   Recuperaria isolamento de processo no Codex, mas introduz dependência
   de um modo/engine externo, é mais difícil de garantir e manter, e
   contraria o princípio do `plan` de **reusar primitivas existentes**.
   Mantido como Tier 1' opcional, não como requisito. Rejeitada como
   baseline.
4. **Construir um engine de "Workflow" próprio no MOSK.** Máximo controle,
   custo de manutenção e superfície de bug altíssimos; reinventa o que o
   filesystem + subagente já dão. Rejeitada (o `plan` já tratava
   "Workflow" como contrato lógico, não primitivo novo).

## Consequências

**Positivas:**

- **Um só** `payload-mode.md` com **um** contrato de orquestração — sem
  dois fluxos divergentes por runtime. O único galho é o adaptador
  `invoke_phase_agent`. Manutenção e previsibilidade altas.
- As partes que determinam a **saída** são idênticas e dirigidas por
  disco → determinístico, auditável, retomável (o `current_phase` permite
  recomeçar de onde parou).
- O leigo tem o **mesmo** transcript pt-BR nos dois runtimes; a promessa de
  paridade fica **honesta** (equivalência de experiência + resultado; o
  isolamento é capacidade do runtime).
- Claude Code **não perde** o isolamento real que já tem.

**Negativas / trade-offs:**

- No Codex (Tier 2), o "headless" é **garantido por disciplina de prompt +
  redirecionamento**, não por isolamento de processo — garantia mais fraca
  que a estrutural do Claude Code. Mitigação: contrato de apresentação
  único + `build-log.md` fora da vista; e o Tier 1' (`codex exec`) como
  caminho de reforço quando disponível.
- FR-030 precisou ser **suavizado** de "idêntica" para "equivalente" — é a
  redação honesta, não uma regressão de escopo.
- Introduz um novo artefato por spec, `build-log.md` (log verboso de
  build, auditável, nunca exibido ao leigo), ao lado de `decisions-log.md`.

## Ajustes aplicados (nesta spec)

- `spec.md` FR-030 e a linha de Edge Case "Codex vs Claude Code":
  "idêntica/igual" → "equivalente", com a nuance de isolamento por
  capacidade de runtime. `SC-007` já dizia "equivalente" (mantido).
- `tasks.md`: **T020** fechado (este ADR); **T019** desbloqueado e
  reescrito para refletir o RAPC + adaptador `invoke_phase_agent` (Tier
  1/Tier 2), o contrato de apresentação único e `build-log.md`.
