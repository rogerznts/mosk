# archive

Arquivar uma spec concluída: promover artefatos canônicos para a base
e mover a pasta para `docs/specs/archive/`.

## User Input

```text
$ARGUMENTS
```

Você **DEVE** considerar o input do usuário antes de prosseguir (se não estiver vazio).

## Guardrails

- Nunca arquive sem `gate: PASS` ou `gate: WAIVED` formalizado. Gate ausente,
  `CONCERNS`, `FAIL` ou waiver incompleto não admite confirmação de bypass.
- Nunca arquive uma spec com tasks pendentes sem confirmar com o usuário.
- Preserve todos os artefatos (spec.md, plan.md, tasks.md, contracts, ADRs, deltas, etc.).
- Nunca sobrescreva um destino existente em modo `copy` sem confirmação explícita do usuário.
- Modo `manual` NUNCA edita a base — apenas lista o que precisa ser aplicado a mão.

## Steps

### 1. Determinar qual spec arquivar

- Se um argumento foi fornecido (número ou nome da pasta), use-o para localizar a spec em `docs/specs/`.
- Caso contrário, liste as pastas disponíveis em `docs/specs/` (excluindo `archive/`) e pergunte ao usuário qual deseja arquivar.
- Confirme o nome exato da pasta antes de continuar.

### 2. Validar prontidão para arquivamento

- Antes de qualquer promoção ou movimento, execute:
  ```bash
  source .claude/mosk/scripts/common.sh
  validate_gate_for_completion "docs/specs/<id>"
  ```
- Se o validador falhar, **interrompa**. Esta condição não pode ser dispensada
  por uma confirmação genérica: `WAIVED` exige `waiver_active: true`, motivo,
  aprovador e timestamp no próprio `gate.yaml`.
- Leia `docs/specs/<id>/tasks.md` e verifique se todas as tasks estão marcadas `- [x]`.
- Se houver tasks pendentes, avise o usuário e peça confirmação explícita para arquivar mesmo assim.
- **Verifique adendos abertos** em `docs/specs/<id>/artefacts/`:
  - Para cada `artefacts/<NNN>-<slug>.md`, leia o front-matter `status:`.
  - Se algum artefato estiver com `status:` diferente de `done`, **interrompa** o arquivamento e liste os adendos pendentes com seus status atuais. Mensagem sugerida: "Resolva ou marque como `done` os adendos abaixo antes de arquivar a spec, ou confirme explicitamente o arquivamento mesmo com adendos abertos."
  - Só prossiga após confirmação explícita do usuário se houver adendos não concluídos.

### 3. Scan de promoção

Percorra `docs/specs/<id>/**/*.md` buscando arquivos com front-matter YAML contendo a chave `promote:`. Para cada um, leia também `promote_mode:` (default: `copy`).

Antes de incluir qualquer item na tabela, valide modo e destino com o helper
compartilhado. Um erro interrompe o archive; não ofereça confirmação para
contornar path inválido:

```bash
source .claude/mosk/scripts/common.sh
REPO_ROOT="$(get_repo_root)"
validated_target="$(validate_promotion_target "$REPO_ROOT" "$promote" "$promote_mode")"
```

O helper exige `copy|append|manual`, restringe o destino a `docs/`, rejeita
caminho absoluto, segmentos `..`/`.` e escapes por symlink. Guarde o caminho
absoluto retornado em `validated_target`; esta é a única variável autorizada
como destino nas operações seguintes.

Monte uma tabela com todos os artefatos encontrados:

| Arquivo | Modo | Destino | Status |
|---|---|---|---|
| docs/specs/<id>/architecture/adr-0007-coupon-service.md | copy | docs/architecture/adr/adr-0007-coupon-service.md | novo |
| docs/specs/<id>/ui/flows/coupon-apply.md | copy | docs/ui/flows/coupon-apply.md | novo |
| docs/specs/<id>/prd-delta.md | manual | docs/prd/ | manual |

Apresente a tabela ao usuário e peça confirmação em bloco (`aplicar tudo`, `pular tudo`, ou resolver item a item).

### 4. Aplicar promoções

Para cada entrada confirmada, execute novamente
`validate_promotion_target` imediatamente antes da escrita e use somente o
`validated_target` retornado:

- **`copy`**: copiar o arquivo inteiro (com front-matter intacto) para `validated_target`. Se o destino já existe, pergunte ao usuário: sobrescrever, pular, ou usar nome alternativo; qualquer nome alternativo também passa pelo helper.
- **`append`**: ler o corpo do arquivo (descartando o front-matter), acrescentar ao final de `validated_target`. Criar o destino se não existir.
- **`manual`**: NÃO aplicar. Apenas imprima o caminho de origem, o destino sugerido e uma instrução clara: "Aplique manualmente o delta abaixo em {destino} antes de considerar a spec concluída."

Para `copy` e `append`, o destino final precisa ser arquivo regular. A validação
de prontidão compara materialmente a promoção: `copy` exige bytes idênticos ao
artefato inteiro; `append` exige que o destino termine com o corpo exato sem o
front-matter. Existência isolada do caminho nunca conta como aplicação.

Se `promote:` for encontrado sem `promote_mode:`, assuma `copy`.

Registre o que foi feito (promovido, pulado, pendente manual) — será usado na nota de encerramento.

### 5. Confirmar o estado arquivado

Depois do gate, das tasks e das promoções estarem satisfeitos, execute:

```bash
bash .claude/mosk/scripts/transition-spec-phase.sh \
  --spec "<id>" --to archived --command archive
```

O comando grava `status`, `archived_at`, `current_phase` e o histórico de forma
atômica. Nunca edite esses campos diretamente.

### 6. Mover a pasta para o arquivo

```bash
mkdir -p docs/specs/archive
mv docs/specs/<id> docs/specs/archive/<id>
```

### 7. Registrar nota de encerramento

Adicione no final de `docs/specs/archive/<id>/spec.md`:

```markdown
---
**Arquivado em:** YYYY-MM-DD
**Status final:** Concluído
**Promoções aplicadas:** {lista breve — copy/append/manual e contagens}
```

### 8. Regenerar `docs/index.md`

Ao final, execute a task `../tasks/index-docs.md` com `docs/` como target. Isso faz a spec descer da tabela "Active Specs" para "Archived Specs" automaticamente. Refresh automático — não pergunte ao usuário, a menos que haja conflitos.

### 9. Oferecer criação de Pull Request (opcional)

Pergunte ao usuário se deseja criar um PR:

- Sugira: `gh pr create --title "feat({id}): <título>" --base <branch-padrão>`
- Aguarde confirmação antes de executar. Pule silenciosamente se recusar.

## Reference

- Use leitura direta de arquivos em `docs/specs/<id>/` para confirmar o estado antes do arquivamento.
- Specs arquivadas ficam em `docs/specs/archive/` e não devem ser editadas.
- Front-matter `promote:` é preservado no arquivo movido para archive — auditabilidade.
- A convenção de promoção está documentada em `.claude/rules/project.md` (Promotion Convention).
