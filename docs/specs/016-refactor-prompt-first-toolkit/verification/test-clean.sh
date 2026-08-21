#!/usr/bin/env bash
# clean_orphans e destrutivo (rm -rf). Prova que remove o orfao e NAO toca no
# legitimo — inclusive na standalone que so DOCUMENTA como se escreve wrapper.
set -u
B=/private/tmp/claude-501/-Users-admin-Projects-mosk/9b98a0a5-f5ac-4707-872a-3a23fb4f4372/scratchpad
FIX="$B/fixture-clean"
pass=0; fail=0

monta() {
  rm -rf "$FIX"; mkdir -p "$FIX"
  cp -R /Users/admin/Projects/mosk/mosk/.claude "$FIX/.claude"
  # orfao 1: wrapper de agente cujo agente nao existe mais
  mkdir -p "$FIX/.claude/skills/mosk-fantasma"
  printf -- '---\nname: mosk-fantasma\n---\nRead the agent definition at .claude/agents/mosk-fantasma.md\n' \
    > "$FIX/.claude/skills/mosk-fantasma/SKILL.md"
  # orfao 2: agente sem fonte no roster
  printf -- '---\nname: mosk-zumbi\n---\n# Zumbi\n' > "$FIX/.claude/agents/mosk-zumbi.md"
}

existe() {
  local nome="$1" caminho="$2" esperado="$3"
  if [ -e "$FIX/$caminho" ]; then local got=existe; else local got=removido; fi
  if [ "$got" = "$esperado" ]; then printf '  ok      %-44s %s\n' "$nome" "$got"; pass=$((pass+1))
  else printf '  FALHA   %-44s %s (esperado %s)\n' "$nome" "$got" "$esperado"; fail=$((fail+1)); fi
}

monta
echo "=== dry-run: nada pode sumir ==="
(cd "$FIX" && bash .claude/mosk/scripts/sync.sh skills --clean --dry-run >/dev/null 2>&1)
existe "orfao sobrevive ao dry-run"   ".claude/skills/mosk-fantasma"  existe
existe "agente orfao sobrevive"       ".claude/agents/mosk-zumbi.md"  existe

monta
echo
echo "=== clean real ==="
(cd "$FIX" && bash .claude/mosk/scripts/sync.sh skills --clean >/dev/null 2>&1)
echo "Deve REMOVER:"
existe "wrapper orfao"                ".claude/skills/mosk-fantasma"  removido
# Pre-existente: o roster vem do proprio CC_AGENTS_DIR, entao a varredura
# local de agentes nunca remove nada. Quem apaga agente que sumiu upstream e o
# reset-install.sh. Afirmado aqui para que a mudanca apareca, se mudar.
existe "agente orfao local (no-op conhecido)" ".claude/agents/mosk-zumbi.md"  existe
echo "Deve PRESERVAR:"
existe "agente legitimo (dev)"        ".claude/agents/mosk-dev.md"    existe
existe "wrapper legitimo (dev)"       ".claude/skills/mosk-dev"       existe
existe "standalone mosk-write-skill"  ".claude/skills/mosk-write-skill" existe
existe "standalone mosk-boot"         ".claude/skills/mosk-boot"      existe
existe "standalone mosk-help"         ".claude/skills/mosk-help"      existe
existe "skill de terceiro (tea)"      ".claude/skills/tea-commit"     existe

echo
echo "total: $pass ok, $fail falhas"
[ "$fail" -eq 0 ]
