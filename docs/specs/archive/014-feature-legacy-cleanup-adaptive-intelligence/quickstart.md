# Quickstart — Verificação end-to-end da Etapa 3

Este roteiro valida o resultado esperado; os nomes finais dos selftests podem ser ajustados na implementação, mas a cobertura não pode diminuir.

## 1. Confirmar baseline

```bash
find mosk/.claude/mosk/tasks -maxdepth 1 -type f -name '*.md' | wc -l
awk -F '\t' 'NR > 1 { count[$2]++ } END { for (k in count) print k, count[k] }' mosk/.claude/mosk/data/task-dispositions.tsv
```

Esperado: 50 itens reconciliados e cada um com exatamente uma disposição.

## 2. Exercitar o classificador

```bash
bash mosk/.claude/mosk/scripts/classify-change.sh \
  --scope localized \
  --reversibility easy \
  --sensitive-surface none \
  --evidence strong \
  --ambiguity clear
```

Esperado: perfil `compact`, validação `focused`, sem especialista obrigatório.

```bash
/bin/zsh mosk/.claude/mosk/scripts/classify-change.sh \
  --scope multi_file \
  --reversibility easy \
  --sensitive-surface data_security \
  --evidence partial \
  --ambiguity bounded
```

Esperado: no mínimo `elevated`, com security no conjunto mínimo. Argumentos ausentes, desconhecidos ou duplicados de forma contraditória devem retornar status diferente de zero sem JSON válido.

## 3. Validar experiência direta

Executar as fixtures de criação documental:

- pedido claro: zero menus e zero pergunta intermediária;
- pedido materialmente ambíguo: uma rodada agrupada;
- pedido explícito de elicitação avançada: capacidade disponível sob demanda;
- ação irreversível: pausa humana preservada.

## 4. Validar fusões e legado

```bash
bash mosk/.claude/mosk/scripts/audit-legacy-surface.sh
bash mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose
```

Esperado: zero task órfã, zero referência quebrada, três capacidades fundidas cobertas no destino e zero ocorrência BMAD operacional fora da allowlist.

## 5. Rodar regressão completa

```bash
bash mosk/.claude/mosk/scripts/selftest-common.sh --verbose
bash mosk/.claude/mosk/scripts/selftest-pipeline-state.sh --verbose
bash mosk/.claude/mosk/scripts/selftest-toolkit.sh --verbose
bash mosk/.claude/mosk/scripts/selftest-adaptive-work.sh --verbose
bash mosk/.claude/mosk/scripts/doctor.sh
```

Repetir os testes portáveis com zsh, validar syntax/ShellCheck, schemas, espelhos e instalação isolada.

## 6. Confirmar redução e gates

- Reexecutar a fórmula da baseline nas 18 tasks de reescrita e confirmar redução operacional mínima de 30%.
- Executar security review diff-aware.
- Executar qa-gate e ciclos automáticos de correção até PASS.
- Parar no PR da Etapa 3; archive e E2E final do programa permanecem posteriores.
