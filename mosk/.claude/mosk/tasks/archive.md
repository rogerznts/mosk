# archive

Arquivar uma spec concluída: promover artefatos canônicos para a base
e mover a pasta para `docs/specs/archive/`.

## User Input

```text
$ARGUMENTS
```

Você **DEVE** considerar o input do usuário antes de prosseguir (se não estiver vazio).

## Guardrails

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

- Leia `docs/specs/<id>/tasks.md` e verifique se todas as tasks estão marcadas `- [x]`.
- Se houver tasks pendentes, avise o usuário e peça confirmação explícita para arquivar mesmo assim.

### 3. Scan de promoção

Percorra `docs/specs/<id>/**/*.md` buscando arquivos com front-matter YAML contendo a chave `promote:`. Para cada um, leia também `promote_mode:` (default: `copy`).

Monte uma tabela com todos os artefatos encontrados:

| Arquivo | Modo | Destino | Status |
|---|---|---|---|
| docs/specs/<id>/architecture/adr-0007-coupon-service.md | copy | docs/architecture/adr/adr-0007-coupon-service.md | novo |
| docs/specs/<id>/ui/flows/coupon-apply.md | copy | docs/ui/flows/coupon-apply.md | novo |
| docs/specs/<id>/prd-delta.md | manual | docs/prd/ | manual |

Apresente a tabela ao usuário e peça confirmação em bloco (`aplicar tudo`, `pular tudo`, ou resolver item a item).

### 4. Aplicar promoções

Para cada entrada confirmada:

- **`copy`**: copiar o arquivo inteiro (com front-matter intacto) para o destino. Se o destino já existe, pergunte ao usuário: sobrescrever, pular, ou usar nome alternativo.
- **`append`**: ler o corpo do arquivo (descartando o front-matter), acrescentar ao final do arquivo em `promote:`. Criar o destino se não existir.
- **`manual`**: NÃO aplicar. Apenas imprima o caminho de origem, o destino sugerido e uma instrução clara: "Aplique manualmente o delta abaixo em {destino} antes de considerar a spec concluída."

Se `promote:` for encontrado sem `promote_mode:`, assuma `copy`.

Registre o que foi feito (promovido, pulado, pendente manual) — será usado na nota de encerramento.

### 5. Atualizar `spec-meta.yaml`

Edite `docs/specs/<id>/spec-meta.yaml`:

- `status: archived`
- `archived_at: "<ISO 8601 UTC atual>"`
- `current_phase: archived`

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
