# QA — evidência do gate da spec 016

**Revisor:** Joaquim (mosk-qa) · **Data:** 2026-08-20
**Perfil adaptativo:** `elevated` · score 6 · validação `independent` · especialistas `qa`, e `security` por superfície tratada
*(escopo `public_contract`, reversibilidade `coordinated`, superfície `paths_state`, evidência `strong`, ambiguidade `clear`)*

Método: cada critério foi verificado **contra o disco**, não contra o `[x]` do `tasks.md`. Marcação registra trabalho alegado; não é prova.

## Critérios de sucesso

| id | critério | medido | veredito |
|---|---|---|---|
| SC-001 | `scripts/*.sh` ≤ 1.500 linhas (sem `payload-*`) | **2.798** | ❌ **não atingido** |
| SC-002 | zero `selftest-*.sh` | 0 arquivos | ✅ |
| SC-003 | todo script remanescente com chamador nominal | 6/6 têm | ✅ |
| SC-004 | spec fora de `archived` reprova | `prerequisites --for archived` reprova a 016 | ✅ |
| SC-005 | fases e arestas de um único arquivo | 6 fases, 6 arestas em `pipeline.yaml` | ✅ |
| SC-006 | corrida retomável sem `run-state.yaml` | template removido; estado em `run-log` front-matter | ✅ |
| SC-007 | nenhum documento vigente manda mover regra para Bash | busca vazia | ✅ |
| SC-008 | instalação limpa valida sem dependência externa | `validate.sh install` OK com `PATH` sem `python3` | ✅ |

**7 de 8.**

## Requisitos funcionais

Verificados por amostragem dirigida aos que dependem de comportamento, não de redação:

- **FR-001/002** — `pipeline.yaml` declara fases, arestas, condições e artefatos; as seis tasks de fase referenciam o contrato em vez de repetir a regra. Duas ocorrências residuais de vocabulário (`specify -> plan` em `full-spec.md`, a lista de vereditos em `qa-gate.md`) são citação de fluxo e de domínio, não reafirmação de regra. Aceitas.
- **FR-003/005/006** — 6 scripts, todos com chamador; `validate.sh` cobre os quatro auditores mais `single-source` e `self-check`.
- **FR-004** — ver SC-001. Não cumprido.
- **FR-007** — confirmado empiricamente com `PATH` sem `python3`.
- **FR-008** — `hooks/guard-spec-merge.sh` registrado em `.claude/settings.json` e ativo.
- **FR-009** — `rule-migration-audit.md` cobre as 9 regras, com origem e destino. A conferência recuperou duas que o plano não previa (`validate_spec_metadata`, `validate_phase_history`) e uma que só existia em código (`human_pause`).
- **FR-010/011/012/016** — `orq-run.md` materializa o plano, declara `mode_effective`, guarda estado no front-matter; as cinco US da 015 conferidas em `spec-015-requirements-check.md`.
- **FR-013/014/015** — ADR-0021 publicado, roadmap emendado, regra de decisão em três lugares incluindo o template que chega aos consumidores.

## Segurança

`docs/qa/security/security-review-016-refactor-prompt-first-toolkit.md` — **SECURITY: PASS**.

Três achados abertos na primeira volta (SEC-001 HIGH, SEC-002 MEDIUM, SEC-003 LOW), todos corrigidos e reverificados: sonda de bypass 9/9 bloqueados, `--extends` 10/10 nas duas camadas, contenção de caminho 7/7 inalterada.

O piso de especialista do perfil está satisfeito com evidência independente.

## Verificações executadas

| bateria | resultado |
|---|---|
| `validate.sh all` (template) | limpo, `fixtures 22/22` |
| `validate.sh all` (mirror) | limpo, `fixtures 22/22` |
| matriz do hook (20 casos) | 20/20 |
| sonda de bypass (9 vetores) | 9/9 bloqueados |
| SEC-003 (10 casos, 2 camadas) | 10/10 |
| `validate.sh install` sem `python3` | OK |

## Achados

### QA-1 — Um critério de sucesso declarado não foi atingido (CONCERNS)

**SC-001 e FR-004** pedem ≤ 1.500 linhas de shell. O resultado é **2.798** — 87% acima da meta.

A entrega material é sólida: 7.912 → 2.798 é **65% de redução**, 25 scripts viram 6, os self-tests somem, nenhum órfão resta. O *objetivo* da spec foi cumprido. O *critério* não.

Examinei a justificativa registrada em `cut-report.md` — de que a meta foi estimada antes de os scripts serem lidos — e ela se sustenta: o mesmo erro de estimativa aparece três vezes na spec (`create-new-feature` previsto em 300 e real em 616; `common.sh` previsto em 6 funções e real em 18; o total). Também confirmei a afirmação de que restam apenas ~150 linhas cortáveis sem perda de função, o que deixaria 2.648 — ainda longe de 1.500. **A meta não era alcançável sem sacrificar comportamento.**

Isso explica o desvio, mas não o dispensa. Um critério de sucesso que a entrega não cumpre exige decisão humana explícita: recalibrar a meta com o número real, aceitar o desvio registrado, ou financiar um corte adicional. Nenhuma dessas é decisão de QA.

### QA-2 — Nada verifica que as tasks seguem o `pipeline.yaml` (CONCERNS)

A tese da spec é que a regra vira dado declarativo lido pelo agente. O `self-check` do `validate.sh` confere que **as constantes do próprio script** batem com o `pipeline.yaml` — três comparações, todas internas ao script.

**Nenhuma verificação cobre as tasks.** Se alguém editar uma aresta no `pipeline.yaml` e as seis tasks de fase continuarem descrevendo o fluxo antigo, nada acusa. O AS-4 da US1 foi provado uma vez, manualmente, na T014; não sobrou fixture.

Isto é o ponto exato onde a premissa revertida pela Etapa 2 tinha razão: *regra escrita em prompt não é garantia*. O ADR-0021 respondeu que o fato passa a viver num lugar único e verificável — e a primeira metade foi entregue, a segunda não. O que existe hoje é a fonte única; falta o verificável.

Não é bloqueante: o `pipeline.yaml` é novo, as tasks foram escritas junto com ele, e não há divergência **hoje**. O risco é de deriva futura, e ele cresce a cada edição.

**Sugestão:** uma verificação em `validate.sh` que extraia do `pipeline.yaml` as fases e arestas e confirme que nenhuma task cita transição fora do declarado. Escopo pequeno; fecha o laço da tese central.

## Score

Fórmula canônica de `qa-evidence-contract.md`: `100 − (20 × FAILs) − (10 × CONCERNS)`.

`0 FAIL, 2 CONCERNS` → **80**.

## Veredito

**CONCERNS.**

Não é `PASS` porque um critério de sucesso declarado não foi atingido (QA-1) e a verificação que sustenta a tese central da spec não existe (QA-2). Nenhum dos dois é defeito de execução; ambos exigem decisão que não é minha.

Não é `FAIL` porque a entrega é substancial, verificada e coerente: a regra está declarada, o corte aconteceu, o guardrail funciona e foi endurecido sob review independente, e nenhum requisito da spec anterior foi perdido.

As escolhas humanas são: corrigir QA-2 e recalibrar SC-001, aceitar ambos com registro, ou formalizar um `WAIVED`.

---

# Correção da volta 1 (`apply-qa-fixes`, 2026-08-21)

## QA-2 — resolvido

Criado `validate.sh tasks-sync`, que fecha o elo que faltava:

```
tasks  ≡  constantes do validate.sh  ≡  pipeline.yaml
   └── tasks-sync ──┘        └── self-check ──┘
```

O `tasks-sync` extrai de cada task as declarações `transition to \`<fase>\` with command \`<cmd>\`` (e a forma em português) e confere contra `CONFIRMA`, a constante que espelha `phases[].confirmed_by`. Verifica os dois sentidos:

- **task → regra**: fase inexistente ou comando que não confirma aquela fase reprovam;
- **regra → task**: aresta declarada que nenhuma task exerce reprova, porque é aresta morta — ou a regra sobra, ou a task sumiu.

O `self-check` foi estendido para ancorar `CONFIRMA` no `pipeline.yaml`. Sem isso o `tasks-sync` validaria as tasks contra uma constante que poderia ter derivado da fonte sem ninguém notar.

Roda em shell puro, sem parser: compara contra as constantes, e é o `self-check` que as prende à fonte.

**Achado na primeira execução.** A verificação reprovou de saída: `implement.md` quebrava a declaração entre duas linhas e o padrão não casava, então a transição `implement:implement` aparecia como aresta sem quem a exercesse. Corrigido na task. A verificação encontrou uma inconsistência real antes de ter sido usada uma única vez de propósito.

**Teste de mutação — 6/6.** Uma verificação que nunca falha não prova nada, que é justamente o defeito que esta foi criada para corrigir. As quatro mutações e o baseline:

| mutação | esperado | resultado |
|---|---|---|
| *(baseline, sem mutação)* | passa | passou |
| `confirmed_by` alterado no `pipeline.yaml` | `self-check` reprova | reprovou |
| task declara comando que não confirma a fase | `tasks-sync` reprova | reprovou |
| task declara fase inexistente | `tasks-sync` reprova | reprovou |
| aresta na regra sem task que a exerça | `tasks-sync` reprova | reprovou |

## QA-1 — não resolvido, e por decisão

O corte adicional identificado no `cut-report.md` (~150 linhas, fundindo as quatro funções de resolução sobrepostas em `common.sh`) **não foi executado**.

Razão: ele levaria 2.798 → ~2.650, contra uma meta de 1.500. Não fecha o critério, e mexe em `resolve_spec_dir`, que está coberto e funcionando. Trocar risco por um número que continua fora da meta não é uma melhora — é movimento.

O achado permanece aberto para decisão humana, como o gate registrou: recalibrar o critério com o número real, aceitar o desvio, ou financiar um corte que chegue de fato a 1.500 (o que exigiria remover função, não gordura).

## Estado após a correção

| bateria | resultado |
|---|---|
| `validate.sh all` (template e mirror) | limpo, incluindo `tasks-sync` |
| fixtures | 22/22 |
| mutação do `tasks-sync` | 6/6 |

---

# Volta 2 do gate — 2026-08-21

## QA-2 — resolvido

`validate.sh tasks-sync` fecha o elo `tasks ≡ constantes ≡ pipeline.yaml`, nos
dois sentidos, e o teste de mutação prova que **reprova** em 6 de 6 casos. Aceito.

Registro o que essa correção rendeu além do escopo: a verificação reprovou na
primeira execução por um motivo real — `implement.md` quebrava a declaração de
transição entre duas linhas — e o teste de mutação, ao ser blindado, revelou que
duas de suas próprias mutações vinham passando sem serem aplicadas. Verificação
que não falha quando deveria é o defeito que este achado descrevia; encontrá-lo
dentro do próprio remédio é a confirmação de que o remédio era necessário.

## QA-1 — dispensado (`WAIVED`)

Não foi resolvido, e não foi resolvido por decisão registrada, não por omissão.

O corte adicional foi executado no que era seguro — código morto, boilerplate do
parse e blocos duplicados do `clean_orphans`, todos com bateria própria —
levando 2.670 → **2.563**. A meta é 1.500.

O autor do projeto dispensou o critério. A justificativa está nos campos de
waiver do `gate.yaml`, e é a que a evidência sustenta: chegar a 1.500 exigiria
apagar os comentários que registram armadilhas já pagas e eliminar ao menos duas
capacidades do toolkit. Os cinco scripts remanescentes existem cada um por um
caso da lista fechada do ADR-0021 — a decisão que restringe shell a corrida no
remoto, geração de derivados e execução fora da sessão do agente.

**O que aceito e o que não aceito.** Aceito que a meta era inatingível — verifiquei
o custo item a item antes de concordar. Não aceito que isso vire precedente: uma
meta ajustada depois de não ser atingida só é legítima quando a evidência mostra
que ela media a coisa errada, e essa demonstração precisa vir antes da dispensa,
não depois. Aqui veio.

**Recomendação que sobrevive ao waiver:** não herdar o número 1.500 em spec
futura. Se um teto de shell voltar a existir, que seja medido a partir do
inventário, não estimado antes dele. Nesta spec, estimativa de corte errou
**quatro vezes**, sempre para baixo — e é o padrão mais reaproveitável que ela
produziu.

## Score

`0 FAIL, 1 CONCERNS` (QA-2 fechou) → **90**. Trajetória: `[80, 90]`.

## Veredito

**WAIVED** — `waiver_active: true`, aprovado por Roger, com motivo e timestamp
registrados no `gate.yaml`, como `gate.allows_completion` exige.

O gate deixa de bloquear a conclusão. Resta a promoção do ADR-0021 para
`docs/architecture/adr/`, que o archive aplica.
