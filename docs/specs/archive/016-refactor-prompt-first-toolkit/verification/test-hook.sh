#!/usr/bin/env bash
# Matriz do guard-spec-merge.sh.
# Estamos numa spec NAO arquivada: verificar => rc=2, ignorar => rc=0.
cd /Users/admin/Projects/mosk || exit 1
H=.claude/hooks/guard-spec-merge.sh
G="gh"; P="pr"; M="merge"; C="create"; T="git"
pass=0; fail=0
t() {
  local nome="$1" cmd="$2" esperado="$3" json out rc
  json="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")"
  out="$(printf '%s' "$json" | bash "$H" 2>&1)"; rc=$?
  if [ "$rc" = "$esperado" ]; then
    printf '  ok      %-40s rc=%s\n' "$nome" "$rc"; pass=$((pass+1))
  else
    printf '  FALHA   %-40s esperado=%s obtido=%s\n' "$nome" "$esperado" "$rc"; fail=$((fail+1))
  fi
}

echo "A. Deve IGNORAR (rc=0) — mencao, nao invocacao:"
t "comando comum"              "ls -la"                                      0
t "mencao em echo"             "echo 'rode $G $P $M depois'"                 0
t "mencao em grep"             "grep -r '$T $M' docs/"                       0
t "REG: heredoc"               "cat <<EOF
$G $P $M 1
EOF"                                                                          0
t "REG: msg de commit"         "$T commit -m 'intercepta $G $P $M,
$G $P $C e $T $M, e esta ativo'"                                              0
t "path com merge no nome"     "cat .claude/hooks/guard-spec-$M.sh"          0
t "git commit (nao merge)"     "$T commit -am wip"                           0
t "substring colada"           "my$G $P $M"                                  0

echo
echo "B. Deve VERIFICAR/BLOQUEAR (rc=2) — invocacao real:"
t "invocacao direta"           "$G $P $M 21 --squash"                        2
t "apos &&"                    "$T push && $G $P $M 21"                      2
t "apos ;"                     "echo oi; $G $P $M 21"                        2
t "git merge"                  "$T $M feature/016-x"                         2
t "gh pr create"               "$G $P $C --fill"                             2

echo
echo "C. SEC-001 — os sete bypasses encontrados na review:"
t "newline separando"          "echo oi
$G $P $M 21"                                                                  2
t "prefixo de env"             "FOO=bar $G $P $M 21"                         2
t "caminho absoluto"           "/usr/bin/$G $P $M 21"                        2
t "command builtin"            "command $G $P $M 21"                         2
t "<< dentro de string"        "echo \"a << b\"; $G $P $M 21"                2
t "<< aritmetico"              "echo \$((1 << 2)); $G $P $M 21"              2
t "aspas nao fechadas"         "echo 'aberta ; $G $P $M 21"                  2

echo
echo "total: $pass ok, $fail falhas"
[ "$fail" -eq 0 ]
