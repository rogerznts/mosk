
# Glossário — termos de domínio

Termos de domínio puros (sem detalhe de implementação). Fixados durante o
`grill` da spec `005-feature-delivery-loop`; ampliado pela spec
`010-feature-graph-loop-orca` (fan-out, join, score e a desambiguação de
*handoff*).

## Delivery-loop

Loop de **convergência limitada** sobre o ciclo de entrega de uma spec:
`corrigir → (revisão de segurança, se aplicável) → gate`, repetido até
**convergir** (gate `PASS`/`WAIVED`) ou **esgotar** o teto de tentativas
(`max_retries`). É **consultivo**: nunca itera sozinho — a cada volta
apresenta o estado e as jogadas legais, e o humano decide. Distingue-se do
loop do bench pela **audiência**: o delivery-loop atende um **operador
técnico** e pode **pausar para tirar dúvidas técnicas**.

## Loop-until-green (bench)

Loop de convergência do modo bench, **por-tarefa** e **automático** (não faz
perguntas), voltado a um usuário **leigo**. Compartilha com o delivery-loop
apenas o *conceito* (loop limitado) e o teto padrão de 3; são mecanismos
distintos. Ver [[delivery-loop]].

## Convergência (de uma spec)

Estado em que a entrega de uma spec atinge um veredito de qualidade
aceitável — o **gate** em `PASS` ou `WAIVED`. É o sinal **único** de "tasks
concluídas": os itens de trabalho alimentam o gate, mas não são um critério
de saída paralelo.

## max_retries

Teto de **voltas do gate** de um delivery-loop, por-spec. Ao ser atingido, o
loop não desiste em silêncio nem continua sozinho: apresenta as jogadas
**escalar / waive / parar**. Padrão: 3.

## Onda

Conjunto de **unidades de trabalho independentes** despachadas juntas dentro de
uma mesma fase, encerrado por um [[join]]. Uma onda não é uma fase: o ponteiro
de fase **não se ramifica**, e a onda inteira conta como **uma** entrada no
histórico — é isso que mantém o contador de [[max_retries]] honesto.

Não confundir com as tentativas do [[delivery-loop]]: aquelas são voltas do
gate, por-spec; a onda é o que acontece **dentro** de uma volta.

## Unidade de trabalho

Item de trabalho executado isoladamente dentro de uma [[onda]], que devolve um
**status curto** — nunca o relato completo do que fez. O estado que importa vive
no disco, não no contexto de quem executou.

## Plano de fan-out

Descrição da [[onda]] apresentada ao humano **antes** de qualquer disparo: quais
unidades, como se agrupam, o critério de aceite de cada uma, o teto de tentativas
e o caminho sequencial equivalente. Aprová-lo é uma **decisão de rota** — e é a
única aprovação pedida: depois dela, nenhuma confirmação por ramo.

## Join

Ponto em que uma [[onda]] se fecha, quando **toda** unidade assentou (convergiu,
falhou ou foi suspensa). O resultado consolidado volta **sempre** ao humano.
Nenhuma onda encadeia outra por conta própria: continuar é decisão de rota.

## quality_score

Nota de 0 a 100 registrada ao lado do veredito do gate. É **calculada** a partir
dos achados, não estimada — o que a torna comparável entre voltas. Serve para
enxergar **trajetória**: um score parado ao longo das tentativas indica
estagnação (a causa é de design ou de story, e a jogada honesta é escalar); um
score subindo indica [[convergência-de-uma-spec]] lenta. **Nunca decide nada** —
o veredito do gate segue sendo o árbitro único.

## Handoff (dois sentidos — cuidado)

O termo significa coisas **opostas** dentro e fora do MOSK:

- **No MOSK** (`/mosk-handoff`): transportar **contexto** de um agente para o
  próximo, **sob supervisão** — o pipeline continua sendo conduzido.
- **No Orca**: transferir **posse** do trabalho; quem entrega **para** de
  acompanhar, e não deve criar tarefa, esperar conclusão nem monitorar.

Confundir os dois desliga a supervisão exatamente onde ela deveria continuar.
