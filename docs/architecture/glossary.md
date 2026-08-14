
# Glossário — termos de domínio

Termos de domínio puros (sem detalhe de implementação). Fixados durante o
`grill` da spec `005-feature-delivery-loop`; ampliado pela spec
`010-feature-graph-loop-orca` (fan-out, join, score e a desambiguação de
*handoff*).

> **Nota (2026-08-14).** Seis verbetes — *Delivery-loop*, *max_retries*, *Onda*,
> *Unidade de trabalho*, *Plano de fan-out* e *Join* — descreviam a camada de
> orquestração removida pelo [ADR-0018](./adr/adr-0018-remove-orchestration-layer.md).
> Foram retirados daqui; a definição de cada um segue legível nos ADRs superseded.

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

## quality_score

Nota de 0 a 100 registrada ao lado do veredito do gate. É **calculada** a partir
dos achados, não estimada — o que a torna comparável entre voltas. Serve para
enxergar **trajetória**: um score parado ao longo das tentativas indica
estagnação (a causa é de design ou de story, e a jogada honesta é escalar); um
score subindo indica [[convergência-de-uma-spec]] lenta. **Nunca decide nada** —
o veredito do gate segue sendo o árbitro único.

## Handoff

`/mosk-handoff` compacta a sessão atual num documento de transição em
`docs/handoff/`, amarrado à spec ativa. Transporta **contexto** para a próxima
sessão ou o próximo agente — não transfere posse do trabalho nem encerra a
supervisão de quem entrega.

Fora do MOSK o termo costuma significar o oposto (transferir posse, e parar de
acompanhar). Vale conferir o sentido quando ele aparecer em ferramenta de
terceiro.
