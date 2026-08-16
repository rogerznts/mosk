# Run log — decisões tomadas sem supervisão

Registro append-only do `/mosk-orq`. Cada linha é uma decisão que a corrida tomou
sozinha, e o motivo. É o que torna a autonomia auditável depois do fato.

| quando | onda | unidade | agente | decisão | por quê |
|---|---|---|---|---|---|
| 2026-08-15T20:16:55Z | 1 | spec-013 | mosk-orq | consolidou a implementação e a primeira rodada de correções em um commit local | T001–T035 concluídas; validações mecânicas 29/29, 142/142 e 39/39 passaram |
| 2026-08-15T20:34:52Z | 2 | SEC-3/SEC-4/SEC-5 | dev-013-security-round2 | corrigiu truncamento de histórico, chaves YAML citadas e validação material de promoções | SECURITY: CONCERNS identificou três regressões médias reproduzidas em Bash e zsh |
| 2026-08-15T20:44:50Z | 3 | SEC-3/SEC-4 | dev-013-security-round2 | amarrou migração ao schema legado e recusou chaves YAML fora da gramática | revalidação adversarial encontrou bypass por origin:migration autodeclarado e escapes Unicode |
| 2026-08-15T21:01:05Z | 4 | QA-3/SEC-4 | dev-013-security-round2 | recusou mappings YAML indentados e promoções ocultas por sintaxe alternativa | gate FAIL score 80 demonstrou archive indevido com destino copy ausente |
