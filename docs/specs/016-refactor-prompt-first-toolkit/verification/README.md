# Verificações da spec 016

Baterias usadas para provar as correções desta spec. **Não são self-tests de
shell** no sentido que o ADR-0021 §6 — *o que se prova é que o dado declarado e
o prompt que o lê concordam* — descartou: são o registro reproduzível de
achados concretos, e cada uma nasceu de um defeito real.

Ficam aqui, junto da spec que as motivou, e não em `scripts/`. Quando a spec for
arquivada, elas congelam com ela.

| bateria | casos | o que provou |
|---|---:|---|
| `test-hook.sh` | 20 | os sete bypasses do SEC-001 — *guardrail contornável* — fechados, sem regressão dos oito casos de menção |
| `test-parse.sh` | 16 | o parse refatorado aceita e recusa o mesmo que antes, incluindo `--number 010` (base 10) e `--extends` endurecido |
| `test-clean.sh` | 10 | `clean_orphans` remove o órfão e preserva legítimo, standalone e skill de terceiro |
| `test-sec003.sh` | 10 | `--extends` recusa injeção nas duas camadas |
| `test-mutacao.sh` | 6 | `tasks-sync` e `self-check` **reprovam** quando as tasks e o `pipeline.yaml` divergem |

## Duas lições que estas baterias registram

**Mutação é o que separa verificação de decoração.** O `test-mutacao.sh` existe
porque uma verificação que nunca falha não prova nada — que é exatamente o
defeito (QA-2 — *nada verifica que as tasks seguem o pipeline.yaml*) que ela foi
criada para corrigir. Duas de suas mutações já passaram silenciosamente por não
terem sido aplicadas de fato; hoje cada uma carrega um `assert` que falha alto
se o alvo mudar de nome.

**Teste que cobre só um lado cobre o lado errado.** As fixtures originais do hook
cobriam menção-tratada-como-invocação, o falso positivo que já tinha mordido. O
falso negativo — invocação não reconhecida — ficou descoberto, e foi ali que a
security review encontrou as sete brechas.
