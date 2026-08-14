---
promote: docs/architecture/adr/adr-0010-orca-backend.md
promote_mode: copy
---

# ADR-0010 — Atuador plugável do `/mosk-orq`: Orca como segundo backend

- Status: **superseded** por [adr-0018](./adr-0018-remove-orchestration-layer.md) (2026-08-14) — o subagente nativo dos runtimes tornou a camada de orquestração redundante. Preservado como registro.
- Data: 2026-07-25
- Autor: spec `007-feature-mosk-orca`
- Contexto: destravar o `/mosk-orq` em ambientes Orca sem duplicar o orquestrador nem relaxar a invariante consultiva.
- Depende de: [adr-0009](./adr-0009-herdr-orchestration.md) (orquestração multi-pane; este ADR generaliza o atuador que ele fixou no Herdr), [adr-0006](./adr-0006-consultative-orchestration-graph.md) (grafo consultivo — invariante preservada), [adr-0008](./adr-0008-consultative-delivery-loop.md) (delivery-loop).

## Contexto

O ADR-0009 deu ao `/mosk-orq` um atuador — o **Herdr** — e o encapsulou em
`scripts/herdr.sh`. A separação cérebro/atuador/transporte já estava certa: o
grafo decide, o `/mosk-handoff` transporta, o `herdr.sh` atua. Só que o atuador
foi tratado como **o** atuador, não como **um** atuador: o `orq.md` chama
`herdr.sh` por caminho fixo em nove pontos.

O ambiente de trabalho migrou para o **Orca** (onorca.dev), um ADE que roda
agentes em worktrees isolados. Dentro de um terminal do Orca, `herdr.sh check`
falha e o Mauro degrada para o fluxo single-pane — a feature inteira some
justamente onde ela seria mais útil.

Três fatos moldam a decisão:

1. **A paridade mecânica é total.** Cada subcomando do `herdr.sh` tem
   equivalente direto em `orca terminal …` (`create`, `send --enter`,
   `wait --for tui-idle`, `read --cursor`, `close`, `list`). A única lacuna é o
   contador de tokens, que o Orca não expõe — e que já era parse da TUI no
   Herdr.
2. **O Orca oferece mais do que paridade.** `orca orchestration` traz task DAG
   com dependências, `dispatch --inject` (preâmbulo de lifecycle), espera por
   evento (`check --wait --types worker_done,escalation,decision_gate`) e
   decision gates. Isso mapeia quase 1:1 no modelo MOSK — mas também traz um
   coordinator loop autônomo (`orchestration run`) que colide de frente com o
   ADR-0006.
3. **`orca` é ambíguo no Linux.** Fora de um terminal do Orca, `orca` costuma
   resolver para `/usr/bin/orca`, o **leitor de tela do GNOME** — invocá-lo
   inicia síntese de voz na máquina do usuário. Um erro de resolução aqui não é
   um comando que falha; é um efeito colateral visível e confuso.

## Decisão

**1. O atuador vira plugável, atrás de um dispatcher.** `scripts/panes.sh` é a
fachada única que o `orq.md` conhece; ele resolve o backend e delega o argv
inalterado para `herdr.sh` ou para o novo `orca.sh`. O contrato de subcomandos
(`check | tokens | spawn | send | wait-idle | read | close | managed`) é o
**mesmo** nos dois — mesmos flags, mesmo formato de saída. O `orq.md` não sabe
qual backend está ativo, e adicionar um terceiro não custa uma linha de prompt.

**2. `orca.sh` espelha o contrato do `herdr.sh`, não o CLI do Orca.** As
divergências são absorvidas no wrapper: `--cwd` vira seletor
`--worktree path:<p>`, `pane_id` e `handle` circulam como o mesmo identificador
opaco, `send` usa o `--enter` atômico (dispensando o `sleep` + `send-keys` que o
Herdr exigia), e `tokens` reusa o mesmo `awk` de extração — promovido a
`common.sh` para não existir em duas cópias.

**3. Resolução de binário explícita e defensiva.** A ordem é
`$ORCA_CLI_COMMAND` → `orca-dev` (quando `$ORCA_DEV_REPO_ROOT`) → `orca-ide` →
`orca`, e o wrapper **recusa** um candidato cujo caminho seja `/usr/bin/orca`.
Nenhum agente invoca `orca` cru: isso vira guardrail no `orq.md`.

**4. Detecção por ambiente, com override explícito.** `orchestration.driver`
(`auto | herdr | orca | none`) vence tudo. Em `auto`, o desempate é a sessão em
que se está rodando (`ORCA_*` vs `HERDR_*`) — quem executa está dentro de um dos
dois, e esse é o sinal mais confiável. Só então cai para "o primeiro `check` que
passar" e, por fim, `none`.

**5. A camada nativa do Orca é opt-in e nunca resolve julgamento.** Com
`orchestration.orca.native_tasks: true`, o Mauro passa a usar `task-create` +
`dispatch --inject` (ganhando `taskId`/`dispatchId` verificáveis) e a esperar
`worker_done` por evento em vez de fazer polling de idle. `judgment` guards e
vereditos de gate viram decision gates do Orca — mas o Mauro **cria** o gate,
apresenta ao humano e só chama `gate-resolve` com a resposta recebida. O
coordinator loop autônomo (`orchestration run`) **não é usado**. Padrão:
desligado — com `native_tasks: false` o comportamento é idêntico ao da paridade.

**6. Base branch por commit, não por nome.** `create-new-feature.sh` passa a
aceitar como base um branch que aponte para o **mesmo commit** de uma base
conhecida. Cada worktree do Orca tem branch próprio (ex.: `rogerznts/master`) e
a base fica ocupada por outro worktree; sem isso, criar spec de dentro do Orca é
impossível. Os bloqueios por padrão de ambiente/release e por branch de spec
(`^[0-9]{3}-`) continuam valendo por cima.

**7. Herdr permanece cidadão de primeira classe.** `herdr.sh` não é depreciado
nem reescrito. A chave `orchestration.herdr` sobrevive intacta para não quebrar
instalações existentes.

> **Revogada em 2026-08-04 por [adr-0014](./adr-0014-orca-single-actuator.md).**
> O Orca passa a ser o atuador único: `herdr.sh` é removido, `orchestration.driver`
> reduz a `auto | orca | none` e `orchestration.herdr` deixa de existir. As demais
> decisões deste ADR (1–6) permanecem vigentes — inclusive a fachada `panes.sh`,
> mantida deliberadamente mesmo com um único backend. O ADR-0014 §4 também altera
> o default de `native_tasks` (§5 deste ADR) de `false` para `auto`.

## Consequências

- **Positivas:** o `/mosk-orq` funciona no ambiente real de trabalho; o custo de
  um backend novo cai para um script que implementa oito subcomandos; a
  invariante do ADR-0006 fica mais explícita do que antes (agora há um ponto do
  design onde ela poderia ter sido violada — `orchestration run` — e a recusa
  está escrita); o `orq.md` encolhe o acoplamento em vez de crescer.
- **Custos/limites:** mais uma camada de indireção entre o agente e o atuador;
  dois wrappers a manter em paridade (mitigado por o contrato ser pequeno e
  fechado, e por `_extract_tokens` ser compartilhado); o parse do contador de
  tokens continua dependendo do layout da TUI nos dois backends.
- **Risco residual:** se um backend divergir silenciosamente no formato de
  saída, o `orq.md` quebra sem erro claro. Mitigação: `panes.sh driver` como
  ponto de inspeção e a checagem de paridade subcomando a subcomando na
  verificação da spec.
- **Fora de escopo (v2):** `create-new-feature.sh` criar/registrar worktree do
  Orca por spec; multi-projeto (N worktrees em paralelo); sensor de tokens via
  hook/statusline gravando em arquivo; backends tmux/zellij.


## Emenda (spec 009) — a paridade é de *contrato*, não de *garantia*

- Data: 2026-07-29
- Autor: spec `009-fix-orca-driver-read-send`

Este ADR afirma que "a paridade mecânica é total: cada subcomando do `herdr.sh`
tem equivalente no `orca.sh`". A spec 009 mantém isso verdadeiro na **superfície**
— nenhum subcomando ou flag novo — e ao mesmo tempo cria uma assimetria de
**garantia** que precisa estar escrita.

**O que mudou.** O `send` do backend Orca passou a confirmar entrega: tira um
snapshot do terminal, injeta, e relê até que **uma sonda distintiva do texto
enviado apareça mais vezes do que aparecia antes**. Devolve exit ≠ 0 quando não
confirma. O `send` do Herdr continua devolvendo o resultado da injeção sem
confirmar.

**A força do predicado é parte da decisão, não detalhe de implementação.** A
primeira versão aceitava qualquer mudança de tela como prova, e isso não
sobrevive ao caso real: a TUI do Claude muda sozinha (spinner, contador de
tokens, medidor de compactação), e uma pane recém-spawnada — o cenário que esta
correção existe para cobrir — é a que mais muda por conta própria. Confirmar por
mudança devolvia exit 0 para entrega perdida, e com exit 0 nenhuma das
salvaguardas do `orq.md` chega a disparar. Quem for portar esta garantia para
outro backend precisa portar **o predicado forte**, não a ideia de "confirmar".

**E precisa portar a escada de sondas junto.** A segunda armadilha é simétrica à
primeira: a TUI **não ecoa verbatim**, ela reformata. Um `/mosk-dev implement …`
pode aparecer como só o token do comando. Exigir um prefixo fixo longo troca o
falso positivo por um falso negativo no formato que o orquestrador mais injeta —
menos perigoso, porque é ruidoso em vez de silencioso, mas suficiente para
transformar a verificação em alarme que ninguém escuta. A implementação tenta
candidatas da mais distintiva para a menos (prefixo longo → primeiro token →
prefixos curtos até um piso), com o piso calibrado para que o prefixo comum
`/mosk-` não confirme nada e o eco de um agente não confirme o envio de outro.

**Troca aceita:** o predicado forte torna falso negativo mais provável (pane que
recebe e não exibe). É o lado seguro — um falso negativo custa uma releitura; um
falso positivo custa uma fase inteira do pipeline, em silêncio.

**Por que a assimetria é aceitável.** O ADR já previa que "o Orca oferece mais do
que paridade"; a garantia extra é do mesmo tipo. O contrato que o `orq.md` consome
não mudou de forma: `send` continua sendo `send <pane> <text>` e continua sinalizando
sucesso/falha por exit code. O que mudou é o que "falha" significa no Orca — e o
`orq.md` foi atualizado para tratar exit ≠ 0 como *entrega não confirmada*, com
releitura obrigatória antes de qualquer reinjeção.

**Por que não levamos o Herdr junto.** Nenhuma perda silenciosa foi relatada nesse
backend, e ampliar a spec para um backend sem defeito observado trocaria correção
verificada por simetria especulativa. Fica registrado como candidato a spec
própria.

**Risco que isto adiciona ao "risco residual" já listado.** Um `orq.md` escrito
assumindo a garantia forte se comporta pior no Herdr do que no Orca: no Herdr, o
exit 0 do `send` continua não sendo prova de entrega. Mitigação: a instrução de
releitura no `orq.md` é escrita como **verificação, não como confiança no exit
code** — vale nos dois backends, e é gratuita onde a confirmação já aconteceu.

**Degradação sem `python3`.** O `read` do Orca agora falha explicitamente quando
não há `python3` utilizável, em vez de devolver um fragmento do envelope. Como a
confirmação do `send` depende do `read`, numa máquina sem `python3` o `send`
degrada para o comportamento antigo (injeta sem confirmar) **avisando em stderr**.
Nunca em silêncio.
