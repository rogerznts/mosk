#!/usr/bin/env bash
# Teste de mutação — QA-2. A verificação só vale se REPROVAR quando o
# pipeline.yaml e as tasks divergirem. Verificação que nunca falha não prova
# nada, que é o defeito que ela mesma foi criada para corrigir.
cd /Users/admin/Projects/mosk || exit 1
V=mosk/.claude/mosk/scripts/validate.sh
Y=mosk/.claude/mosk/pipeline.yaml
T=mosk/.claude/mosk/tasks/plan.md
cp "$Y" /tmp/mut-pipeline.bak; cp "$T" /tmp/mut-task.bak; cp "$V" /tmp/mut-validate.bak
restaura() { cp /tmp/mut-pipeline.bak "$Y"; cp /tmp/mut-task.bak "$T"; cp /tmp/mut-validate.bak "$V"; }
trap restaura EXIT

pass=0; fail=0
checa() {
  local nome="$1" sub="$2" esperado="$3"
  if bash "$V" "$sub" >/dev/null 2>&1; then local got=passou; else local got=reprovou; fi
  if [ "$got" = "$esperado" ]; then
    printf '  ok      %-46s %s\n' "$nome" "$got"; pass=$((pass+1))
  else
    printf '  FALHA   %-46s %s (esperado %s)\n' "$nome" "$got" "$esperado"; fail=$((fail+1))
  fi
}

echo "Baseline (sem mutação):"
checa "self-check limpo"                     self-check passou
checa "tasks-sync limpo"                     tasks-sync passou

echo
echo "Mutação 1 — aresta removida do pipeline.yaml, tasks intactas:"
python3 - <<'PY'
p='mosk/.claude/mosk/pipeline.yaml'; s=open(p).read()
s=s.replace("    confirmed_by: [plan]", "    confirmed_by: [planx]",1)
assert "confirmed_by: [planx]" in s, "mutacao nao aplicada"
open(p,'w').write(s)
PY
checa "self-check pega CONFIRMA divergente"  self-check reprovou
restaura

echo
echo "Mutação 2 — task declara comando que não confirma a fase:"
python3 - <<'PY'
p='mosk/.claude/mosk/tasks/plan.md'; s=open(p).read()
s=s.replace("transition to `plan` with command `plan`", "transition to `plan` with command `archive`",1)
assert "command `archive`" in s, "mutacao nao aplicada"
open(p,'w').write(s)
PY
checa "tasks-sync pega comando errado"       tasks-sync reprovou
restaura

echo
echo "Mutação 3 — task declara fase inexistente:"
python3 - <<'PY'
p='mosk/.claude/mosk/tasks/plan.md'; s=open(p).read()
s=s.replace("transition to `plan` with command `plan`", "transition to `planning` with command `plan`",1)
assert "`planning`" in s, "mutacao nao aplicada"
open(p,'w').write(s)
PY
checa "tasks-sync pega fase inexistente"     tasks-sync reprovou
restaura

echo
echo "Mutação 4 — aresta na regra sem task que a exerça:"
python3 - <<'PY'
p='mosk/.claude/mosk/scripts/validate.sh'; s=open(p).read()
s=s.replace('CONFIRMED_BY="plan:plan tasks:tasks', 'CONFIRMED_BY="plan:plan orfa:orfa tasks:tasks',1)
assert 'orfa:orfa' in s, "mutacao nao aplicada — a constante mudou de nome?" 
open(p,'w').write(s)
PY
checa "tasks-sync pega aresta morta"         tasks-sync reprovou
restaura

echo
echo "total: $pass ok, $fail falhas"
[ "$fail" -eq 0 ]
