# Conferência de migração de regras (T008)

Cumpre o **FR-009**: nenhuma regra é removida antes de existir equivalente declarativo, e regra sem equivalente viável é **nomeada**, não descartada em silêncio.

Método: as 39 funções de `common.sh` foram lidas uma a uma e classificadas em quatro categorias. A distinção que organiza tudo é esta:

> **Regra de domínio** é o que o MOSK decidiu que vale (quais arestas existem, o que um gate precisa ter). Sobrevive à mudança de leitor e migra para o `pipeline.yaml`.
>
> **Defesa do parser** é o que o shell precisou construir para conseguir ler o arquivo com segurança (chave canônica, duplicidade, contagem por ocorrência). Não é regra sobre o MOSK — é regra sobre o leitor, e desaparece junto com ele.

Confundir as duas é o que faria o corte perder garantia. Separá-las é o que o torna barato.

## Resumo

| categoria | funções | destino |
|---|---:|---|
| Regra de domínio → `pipeline.yaml` | 7 | migrada, verificada abaixo |
| Regra de domínio → `adaptive-work-contract.md` | 1 | migrada |
| Defesa do parser → desaparece com o leitor | 8 | sem equivalente, por construção |
| Leitor/escritor de YAML → o agente assume | 7 | sem equivalente, por construção |
| Utilitário de caminho/git → fica em `common.sh` | 12 | permanece |
| Helper do runner → US4 | 2 | tratado na fase 6 |
| Resolução de spec → fica em `common.sh` | 2 | permanece |

## 1. Regra de domínio migrada para `pipeline.yaml`

| função | destino no `pipeline.yaml` | conferido |
|---|---|---|
| `phase_transition_allowed` | `phases[].transitions_to` | ✅ 6 arestas, conferidas uma a uma contra o `case` original |
| `phase_command_matches_destination` | `phases[].confirmed_by` + `restricted_edges` + `wildcard_commands` | ✅ inclui o curinga `migration:*` |
| `validate_phase_preconditions` | `phases[].requires` + `when_from` | ✅ inclui a exigência de gate `FAIL`/`CONCERNS` no retorno a `implement` |
| `validate_gate_contract` | `gate.*` | ✅ campos, domínios, schema 1 legado |
| `validate_gate_for_completion` | `gate.allows_completion` | ✅ `PASS` livre, `WAIVED` com quatro exigências, `FAIL`/`CONCERNS` bloqueiam |
| `validate_spec_promotions_satisfied` | `promotions.satisfied` | ✅ `copy` idêntico, `append` como sufixo do corpo, `manual` isento |
| `validate_spec_metadata` | `spec_meta.*` | ✅ **não estava na tabela do plano** — ver achado abaixo |
| `validate_phase_history` | `phase_history.*` | ✅ **não estava na tabela do plano** — ver achado abaixo |

### Achado: duas regras a mais do que o plano previa

O `plan.md` tabelou 7 regras presas em shell. A leitura função a função encontrou **9**. As duas não previstas:

- **`validate_spec_metadata`** — o schema do `spec-meta.yaml`, incluindo a **identidade cruzada** entre `spec_number`, `spec_id`, `type` e `branch`. Esta é a regra que materializa o ADR-0017 (branch e pasta são strings diferentes, e a ponte é campo a campo, nunca igualdade de string). Perdê-la reabriria exatamente a classe de bug que o ADR-0017 fechou.
- **`validate_phase_history`** — continuidade da cadeia, monotonicidade dos timestamps, e a consistência entre `origin: specify|migration` e a evidência `history_origin_schema`. A parte sutil, que preservei: `origin: specify` **exige** que o primeiro evento seja `specify -> plan`, senão o histórico está truncado; e `origin: migration` exige a evidência do upgrade, para não virar a saída fácil de um histórico incompleto.

Ambas migraram. O plano será corrigido de 7 para 9 na próxima revisão.

## 2. Regra de domínio migrada para `adaptive-work-contract.md`

| função | achado |
|---|---|
| `classify-change.sh` (script, não função) | A tabela de pontuação e os quatro pisos **já estavam** no contrato — o script era reimplementação, não fonte. Mas a regra de **`human_pause`** existia só no script: o contrato a citava apenas no exemplo JSON. Foi declarada agora, com as três condições (`ambiguity: material`, `reversibility: irreversible`, `sensitive_surface: production_critical`) e a nota de que a pausa é sobre prosseguir, não sobre o perfil. |

Sem esta conferência, `human_pause` teria sumido no corte sem que nada acusasse.

## 3. Defesa do parser — sem equivalente, por construção

Estas oito não migram porque **não são regra sobre o MOSK**. Existem porque o leitor era shell, e o ADR-0021 §3 tira o shell da posição de leitor.

| função | o que protegia |
|---|---|
| `validate_canonical_top_level_yaml_keys` | gramática restrita do ADR-0020 |
| `validate_canonical_frontmatter_yaml_keys` | idem, no front-matter |
| `validate_no_duplicate_yaml_keys` | chave repetida que o leitor por `grep` não veria |
| `frontmatter_yaml_key_count` | contagem de ocorrência como defesa |
| `validate_promotion_frontmatter` | forma do front-matter para o leitor em shell |
| `validate_spec_dir_containment` | *(parcial — a contenção física permanece, ver §5)* |
| `validate_spec_storage_root` | *(parcial — idem)* |
| contagem por `awk` dentro de `validate_gate_contract` | "campo deve ocorrer exatamente uma vez" |

**Um parser YAML de verdade trata todos estes casos nativamente.** Chave duplicada, escalar multi-linha, coleção inline, comentário em posição inesperada — nada disso é ambíguo para quem tem um parser; era ambíguo para quem tinha `grep` e `sed`.

## 4. Leitor e escritor de YAML — o agente assume

| função | substituto |
|---|---|
| `read_yaml_scalar`, `read_spec_meta`, `read_frontmatter_scalar` | o agente lê o arquivo |
| `write_spec_meta`, `update_spec_phase` | o agente escreve, a partir do template |
| `extract_frontmatter_body` | o agente separa front-matter de corpo |
| `list_active_specs` | o agente lista e lê |
| `resolve_max_attempts` | leitura de config — o agente lê o `core-config.yaml` |
| `transition_spec_phase` | o agente aplica a transição contra o `pipeline.yaml` |

## 5. Permanece em `common.sh`

Doze utilitários que resolvem **caminho e git**, não dado de domínio — a categoria que o ADR-0021 §4 mantém como shell:

`get_repo_root`, `get_current_branch`, `has_git`, `core_config_file`, `check_dir`, `check_file`, `check_feature_branch`, `get_feature_dir`, `get_feature_paths`, `find_feature_dir_by_prefix`, `find_feature_dir_by_prefix_any`, `infer_repo_root_from_spec_dir`, `resolve_spec_dir`.

Mais duas de contenção, que ficam por uma razão específica:

- **`validate_promotion_target`** e a parte física de **`validate_spec_dir_containment`** / **`validate_spec_storage_root`** — precisam resolver symlink de verdade contra o sistema de arquivos. Um agente pode ler o caminho declarado, mas não pode afirmar para onde um symlink aponta sem consultar o disco. É verificação de sistema, não de dado.

A meta de ~6 funções do plano subestimou: o número realista é **~14**, contando as de contenção. Registro a divergência aqui em vez de forçar o número — cortar utilitário de caminho para bater uma meta reintroduziria a duplicação que `common.sh` existe para evitar.

## 6. Helpers do runner

`append_run_log` e `ensure_runner_gitignore` pertencem à US4 e são tratados na Phase 6, junto com a colheita da 015.

## Conclusão

**Nenhuma regra de domínio foi perdida.** Duas foram recuperadas que o plano não previa (`validate_spec_metadata`, `validate_phase_history`), e uma terceira (`human_pause`) que existia só em código foi declarada pela primeira vez.

**Nenhuma regra ficou sem equivalente por impossibilidade.** As que não migraram não migraram porque protegiam o leitor, não o domínio — e o leitor está sendo trocado.

Duas correções para o plano, registradas e não escondidas:

1. A tabela de regras presas em shell é de **9**, não 7.
2. `common.sh` termina com **~14 funções**, não ~6. A meta de linhas (SC-001) não muda; a de funções era estimativa e estava otimista.
