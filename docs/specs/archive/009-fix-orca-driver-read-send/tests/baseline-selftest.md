# Baseline de falha — `selftest-orca-driver.sh` contra o código pré-correção

**Data:** 2026-07-29 · **Tarefa:** T004

Por que existe: sem este registro, "o selftest passa" não prova nada — uma suíte
que nunca viu o defeito não protege contra ele. O mesmo script foi rodado contra o
`orca.sh` + `common.sh` **antes** das correções (a cópia do mirror da raiz, ainda
não sincronizada na hora) e **depois**.

| | Asserções ok | Veredito |
|---|---|---|
| Pré-correção | 14 | **FALHOU** — 10 asserções |
| Pós-correção | 24 | **OK** |

## Falhas capturadas no código antigo

| Caso | Esperado | Obtido (antes) |
|---|---|---|
| 1. `tail` com 3 linhas | as 3 linhas | `''` (vazio, exit 0) |
| 4. `tail` curto vs. campo longo | `short` | `AAAAAAAA…` (o campo mais longo) |
| 5. `tail` com itens dict | `linha um` + `linha dois` | **só** `linha dois` |
| 6. sem `python3`, 4 fixtures | exit ≠ 0, stdout vazio | exit 0 — e num caso, `AAAAAAAA…` |
| 7a. predicado de confirmação | confirmado | função inexistente |
| 8. `graph_edge_exists` em zsh | `TRUE` | `FALSE` |

## Dois defeitos que nem o relato de campo nem o plano previam

**Caso 5 — leitura parcial silenciosa.** Com `tail` contendo itens `dict`, o
extrator antigo não devolvia vazio: devolvia **uma linha de duas**. O `max(out,
key=len)` colhia cada string separadamente e escolhia a mais longa (`linha dois`,
10 caracteres, vencendo `linha um`, 8). Um caso que aparentava funcionar entregava
metade do conteúdo.

**Caso 6/`FX_TAIL_VS_LONG` — conteúdo errado mas plausível.** O fallback `sed` não
devolvia apenas fragmento de JSON (`{"id":"x`): quando o envelope tinha um campo
`content` em outro ramo, devolvia **esse campo**. Texto limpo, verossímil, e
completamente desligado do terminal. Pior que o fragmento, porque não se parece com
um defeito.

## Como reproduzir o baseline

O `selftest` sourceia o `orca.sh` que estiver **no seu próprio diretório**. Para
rodá-lo contra outra cópia do driver, basta colocá-lo lá:

```bash
cp mosk/.claude/mosk/scripts/selftest-orca-driver.sh <dir-com-o-driver-antigo>/_baseline.sh
bash <dir-com-o-driver-antigo>/_baseline.sh
```
