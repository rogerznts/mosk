#!/usr/bin/env bash
# SEC-003 — --extends deve ser recusado fora do domínio, nas duas camadas.
set -u
FIX=/private/tmp/claude-501/-Users-admin-Projects-mosk/9b98a0a5-f5ac-4707-872a-3a23fb4f4372/scratchpad/fixture-sec003
rm -rf "$FIX"; mkdir -p "$FIX"
cp -R /Users/admin/Projects/mosk/mosk/.claude "$FIX/.claude"
cd "$FIX" || exit 1
git init -q; git config user.name Fx; git config user.email f@x.io; git config commit.gpgsign false
mkdir -p docs/specs; echo seed > README.md; git add -A >/dev/null; git commit -qm seed; git branch -M master

pass=0; fail=0
camada1() {
  local nome="$1" valor="$2" esperado="$3"
  git checkout -q master 2>/dev/null
  bash .claude/mosk/scripts/create-new-feature.sh --no-push --type extension \
       --short-name t --extends "$valor" "desc" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" != "0" ] && [ "$esperado" = "recusa" ]; then
    printf '  ok      %-34s recusou\n' "$nome"; pass=$((pass+1))
  elif [ "$rc" = "0" ] && [ "$esperado" = "aceita" ]; then
    printf '  ok      %-34s aceitou\n' "$nome"; pass=$((pass+1))
  else
    printf '  FALHA   %-34s rc=%s esperado=%s\n' "$nome" "$rc" "$esperado"; fail=$((fail+1))
  fi
}

echo "Camada 1 — create-new-feature.sh --extends:"
camada1 "spec-id valido"        "001-feature-alvo"                   aceita
camada1 "injecao de chave YAML" '001-feature-x"
malicioso: "sim'                                                     recusa
camada1 "tipo invalido"         "001-banana-x"                       recusa
camada1 "numero fora de forma"  "1-feature-x"                        recusa
camada1 "texto livre"           "a spec anterior"                    recusa
camada1 "path traversal"        "../../etc/passwd"                   recusa

echo
echo "Camada 2 — write_spec_meta (defesa em profundidade):"
source .claude/mosk/scripts/common.sh
d="$FIX/probe"; mkdir -p "$d"
c2() {
  local nome="$1" valor="$2" esperado="$3"
  if write_spec_meta "$d" "001" "001-feature-x" feature "feature/001-x" "$valor" 2>/dev/null; then
    local rc=aceita
  else
    local rc=recusa
  fi
  if [ "$rc" = "$esperado" ]; then
    printf '  ok      %-34s %s\n' "$nome" "$rc"; pass=$((pass+1))
  else
    printf '  FALHA   %-34s %s (esperado %s)\n' "$nome" "$rc" "$esperado"; fail=$((fail+1))
  fi
}
c2 "vazio (sem extends)"   ""                        aceita
c2 "spec-id valido"        "001-feature-alvo"        aceita
c2 "injecao direta"        '001-feature-x"
mal: "s'                                             recusa
c2 "aspas no valor"        '001-feature-x"'          recusa

echo
echo "total: $pass ok, $fail falhas"
[ "$fail" -eq 0 ]
