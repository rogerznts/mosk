# Quickstart de validação

Este roteiro será executado numa cópia temporária do template, nunca numa spec
real do repositório.

1. Materialize `mosk/` num diretório temporário e inicialize um repositório Git.
2. Crie uma spec fixture no schema legado e confirme que o diagnóstico a lê sem
   reescrevê-la.
3. Crie uma spec nova e percorra `specify -> plan -> tasks -> implement`.
4. Tente `implement -> archived` e confirme exit 1, mensagem legível e hashes
   inalterados de metadata/histórico.
5. Gere gate `FAIL`, avance a `qa-gate` e retorne a `implement` para correção.
6. Gere gate `PASS` no schema vigente com evidência e avance novamente a
   `qa-gate`.
7. Repita a transição para `qa-gate` e confirme no-op sem evento duplicado.
8. Satisfaça promoções, transicione a `archived`, mova a pasta e confirme
   `check-ship-ready.sh --json` com `ready:true` após limpar a árvore.
9. Repita o cenário com gate sem evidência, waiver incompleto e schema futuro;
   todos devem falhar de forma fechada.
10. Rode `doctor.sh --json` e confirme todos os checks verdes sem PyYAML, npm ou
    pip.
