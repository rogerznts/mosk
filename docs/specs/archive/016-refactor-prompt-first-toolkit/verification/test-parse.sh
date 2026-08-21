#!/usr/bin/env bash
# Parse de argumentos do create-new-feature apos a refatoracao.
set -u
FIX=/private/tmp/claude-501/-Users-admin-Projects-mosk/9b98a0a5-f5ac-4707-872a-3a23fb4f4372/scratchpad/fixture-parse
S=mosk/.claude/mosk/scripts/create-new-feature.sh
cd /Users/admin/Projects/mosk || exit 1
pass=0; fail=0

novo_fixture() {
  rm -rf "$FIX"; mkdir -p "$FIX"
  cp -R /Users/admin/Projects/mosk/mosk/.claude "$FIX/.claude"
  cd "$FIX" || exit 1
  git init -q; git config user.name Fx; git config user.email f@x.io; git config commit.gpgsign false
  mkdir -p docs/specs; echo seed > README.md; git add -A >/dev/null; git commit -qm seed; git branch -M master
}

esperado() {
  local nome="$1" rc_esperado="$2"; shift 2
  bash .claude/mosk/scripts/create-new-feature.sh "$@" >/dev/null 2>&1
  local rc=$?
  local ok
  if [ "$rc_esperado" = "0" ]; then [ "$rc" = "0" ] && ok=1 || ok=0
  else [ "$rc" != "0" ] && ok=1 || ok=0; fi
  if [ "$ok" = "1" ]; then printf '  ok      %-40s rc=%s\n' "$nome" "$rc"; pass=$((pass+1))
  else printf '  FALHA   %-40s rc=%s (esperado %s)\n' "$nome" "$rc" "$rc_esperado"; fail=$((fail+1)); fi
  git checkout -q master 2>/dev/null
}

novo_fixture
echo "Deve ACEITAR:"
esperado "basico"                    0 --no-push "cria alguma coisa"
esperado "com --type"                0 --no-push --type fix "corrige algo"
esperado "com --short-name"          0 --no-push --short-name meu-nome "descricao"
esperado "com --number"              0 --no-push --number 42 "com numero"
esperado "--number com zero a esq"   0 --no-push --number 010 "octal nao"
esperado "com --json"                0 --no-push --json "saida json"
esperado "--extends valido"          0 --no-push --type extension --extends 001-feature-cria-alguma "estende"

echo
echo "Deve RECUSAR:"
esperado "--type invalido"           1 --no-push --type banana "x"
esperado "--type sem valor"          1 --no-push --type
esperado "--type seguido de flag"    1 --no-push --type --json "x"
esperado "--short-name sem valor"    1 --no-push --short-name
esperado "--number nao numerico"     1 --no-push --number abc "x"
esperado "--extends invalido"        1 --no-push --type extension --extends "nao-e-spec-id" "x"
esperado "--extends com injecao"     1 --no-push --type extension --extends '001-feature-x"
mal: "s' "x"
esperado "opcao desconhecida vira arg" 0 --no-push "texto --com-hifen dentro"

echo
echo "=== conferindo efeito real das flags ==="
cd "$FIX" || exit 1
git checkout -q master
bash .claude/mosk/scripts/create-new-feature.sh --no-push --type hotfix --short-name urgente --number 77 "teste efeito" >/dev/null 2>&1
if [ -f docs/specs/077-hotfix-urgente/spec-meta.yaml ]; then
  printf '  ok      %-40s\n' "--number 77 + --type hotfix + --short-name"; pass=$((pass+1))
  grep -E '^(spec_number|type|branch):' docs/specs/077-hotfix-urgente/spec-meta.yaml | sed 's/^/          /'
else
  printf '  FALHA   %-40s (pasta esperada nao existe)\n' "--number/--type/--short-name"; fail=$((fail+1))
  ls docs/specs/
fi

echo
echo "total: $pass ok, $fail falhas"
[ "$fail" -eq 0 ]
