# Run log — decisões tomadas sem supervisão

Registro append-only do `/mosk-orq`. Cada linha é uma decisão que a corrida tomou
sozinha, e o motivo. É o que torna a autonomia auditável depois do fato.

| quando | onda | unidade | agente | decisão | por quê |
|---|---|---|---|---|---|
| 2026-08-15T23:44:11Z | 0 | foundation | mosk-orq | executar stories em série | tasks.md marca paralelismo apenas em tarefas internas e não autoriza paralelismo entre stories |
