
# Glossário — termos de domínio

Termos de domínio puros (sem detalhe de implementação). Fixados durante o
`grill` da spec `005-feature-delivery-loop`.

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
