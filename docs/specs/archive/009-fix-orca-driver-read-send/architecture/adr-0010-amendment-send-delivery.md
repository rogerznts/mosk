---
promote: docs/architecture/adr/adr-0010-orca-backend.md
promote_mode: append
---

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
