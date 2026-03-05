# spec-archive

Arquivar uma spec concluída movendo-a para `docs/specs/archive/`.

## User Input

```text
$ARGUMENTS
```

Você **DEVE** considerar o input do usuário antes de prosseguir (se não estiver vazio).

## Guardrails

- Nunca arquive uma spec com tasks pendentes sem confirmar com o usuário.
- Preserve todos os artefatos (spec.md, plan.md, tasks.md, contratos, etc.).

## Steps

1. Determinar qual spec arquivar:
   - Se um argumento foi fornecido (número ou nome da pasta), use-o para localizar a spec em `docs/specs/`.
   - Caso contrário, liste as pastas disponíveis em `docs/specs/` (excluindo `archive/`) e pergunte ao usuário qual deseja arquivar.
   - Confirme o nome exato da pasta antes de continuar.

2. Validar prontidão para arquivamento:
   - Leia `docs/specs/<id>/tasks.md` e verifique se todas as tasks estão marcadas `- [x]`.
   - Se houver tasks pendentes, avise o usuário e peça confirmação explícita para arquivar mesmo assim.

3. Criar diretório de arquivo se não existir:
   ```bash
   mkdir -p docs/specs/archive
   ```

4. Mover a pasta da spec para o arquivo:
   ```bash
   mv docs/specs/<id> docs/specs/archive/<id>
   ```

5. Registrar o arquivamento:
   - Adicione uma nota de encerramento em `docs/specs/archive/<id>/spec.md` (no final do arquivo):
     ```
     ---
     **Arquivado em:** YYYY-MM-DD
     **Status final:** Concluído
     ```

6. Oferecer criação de Pull Request (se aplicável):
   - Pergunte ao usuário se deseja criar um PR antes ou após arquivar.
   - Sugira o comando: `gh pr create --title "feat({id}): <título>" --base <branch-padrão>`
   - Aguarde confirmação antes de executar. Pule silenciosamente se o usuário recusar.

## Reference

- Use leitura direta de arquivos em `docs/specs/<id>/` para confirmar o estado antes do arquivamento.
- Specs arquivadas ficam em `docs/specs/archive/` e não devem ser editadas.
