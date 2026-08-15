# Run log — decisões tomadas sem supervisão

<!--
  Escrito pelo `/mosk-orq` durante uma corrida autônoma, via `append_run_log`
  (`.claude/mosk/scripts/common.sh`). Vive em `docs/specs/{id}/run-log.md`.

  Append-only e VERSIONADO — é o par do `run-noise.log`, que é efêmero e
  gitignored. A divisão é deliberada: o ruído se joga fora, a decisão fica.

  Este arquivo é o preço da autonomia. Você não viu a corrida acontecer, então
  ele precisa bastar para reconstruir o que foi decidido e por quê. Se uma
  decisão autônoma não está aqui, ela é indistinguível de um acidente.
-->

Registro append-only da corrida autônoma. Cada linha é uma decisão que o runner
tomou sozinho, e o motivo.

| quando | onda | unidade | agente | decisão | por quê |
|---|---|---|---|---|---|
| 2026-08-14T19:10:02Z | 1 | US-1 | dev-us1-fechamento | seguiu com transação única | `plan.md` §4 previa as duas formas e não escolhia; a única reversível |
| 2026-08-14T19:24:51Z | 1 | US-2 | qa-onda-1 | gate CONCERNS, score 70 | `SC-002` sem teste; a unidade volta na onda 2 |
| 2026-08-14T19:41:07Z | 2 | US-2 | dev-us2-relatorio | **parou e devolveu** | teto de 3 voltas atingido com score parado (70 → 70 → 70) |

## O que registrar

**Toda decisão que você tomaria diferente se o humano estivesse olhando.** Na
prática:

- escolha entre dois caminhos que a documentação não decidia (e qual você pegou);
- veredito de gate por onda, com o score;
- unidade que voltou para uma onda seguinte, e por quê;
- invocação que falhou e o que você fez a respeito;
- toda **parada**, com o gatilho exato.

## O que não registrar

Progresso mecânico. "Rodou os testes", "abriu o worktree", "fez o merge" — isso é
ruído, e ruído vai para o `run-noise.log`. Um log de decisões que registra
execução deixa de ser legível exatamente quando você mais precisa dele.

## Regras

- **Uma linha por decisão**, na ordem em que aconteceram.
- **O "por quê" é obrigatório** e cita a fonte: `plan.md §4`, `SC-002`, o veredito
  do gate. Sem fonte, é opinião — e opinião de um processo que ninguém assistiu
  não vale nada.
- **Nunca reescreva nem apague uma linha.** Uma decisão revista vira linha nova.
- Vale o contrato de saída (`data/output-contract.md`): id citado carrega a
  glossa na primeira menção.
