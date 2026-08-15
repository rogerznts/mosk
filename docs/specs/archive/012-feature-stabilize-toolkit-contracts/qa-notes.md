# QA notes — spec 012

- Security review: a primeira rodada sobre `5595122` encontrou SEC-1 no destino
  `promote:`; a segunda rodada revalidou a correção não commitada e concluiu
  [`SECURITY: PASS`](../../qa/security/security-review-012-feature-stabilize-toolkit-contracts.md).
- Quality gate, primeira rodada sobre `5595122`: `FAIL · score 40` — duas
  falhas altas e duas ressalvas médias.
- Quality gate, segunda rodada sobre as correções não commitadas:
  `CONCERNS · score 90` — QA-1, QA-2, QA-3 e SEC-1 resolvidos; QA-4 permaneceu
  aberto por incompatibilidade do helper de promoção com zsh.
- Quality gate, terceira rodada: [`PASS · score 100`](./gate.yaml) — QA-4
  resolvido em zsh real, findings anteriores sem regressão e security review
  ainda aplicável como `SECURITY: PASS`.
