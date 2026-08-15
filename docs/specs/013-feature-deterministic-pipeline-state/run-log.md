# Run log — decisões tomadas sem supervisão

Registro append-only do `/mosk-orq`. Cada linha é uma decisão que a corrida tomou
sozinha, e o motivo. É o que torna a autonomia auditável depois do fato.

| quando | onda | unidade | agente | decisão | por quê |
|---|---|---|---|---|---|
| 2026-08-15T20:16:55Z | 1 | spec-013 | mosk-orq | consolidou a implementação e a primeira rodada de correções em um commit local | T001–T035 concluídas; validações mecânicas 29/29, 142/142 e 39/39 passaram |
