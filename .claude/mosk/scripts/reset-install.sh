#!/usr/bin/env bash
# reset-install.sh — reinstala o toolkit MOSK do zero, apagando a instalação
# anterior antes de copiar a nova.
#
# Por que existe: `npx degit --force` SOBRESCREVE arquivo por arquivo e nunca
# APAGA. Um script, uma skill ou um agente que deixou de existir upstream fica no
# disco do projeto para sempre — e os agentes MOSK continuam encontrando e
# tentando usar. Atualizar sem reset acumula lixo de todas as versões passadas.
#
# Ordem correta de uso (é o que a skill /mosk-update faz):
#   1. npx degit rogerznts/mosk/mosk "$TMP"     # baixa, sem tocar no projeto
#   2. reset-install.sh --dry-run --from "$TMP" --to .   # previa exata
#   3. (usuario confirma)
#   4. reset-install.sh --from "$TMP" --to .    # apaga + instala
#
# Rode SEMPRE a copia recem-baixada (`$TMP/.claude/mosk/scripts/reset-install.sh`),
# nunca a instalada: este script apaga o diretorio onde ele mesmo mora.
#
# Usage:
#   reset-install.sh --from <dir> --to <dir> [--dry-run] [--json] [--help]
set -e

FROM=""
TO=""
DRY_RUN=0
JSON=0

usage() {
    cat <<'EOF'
reset-install.sh --from <dir> --to <dir> [--dry-run] [--json]

Reinstala o toolkit MOSK do zero: apaga a instalacao anterior e copia a nova.
Existe porque `degit --force` sobrescreve mas nunca apaga, deixando orfaos de
versoes passadas no disco do projeto.

Opcoes:
  --from <dir>  raiz do template novo (o que o degit baixou; contem .claude/)
  --to <dir>    raiz do projeto que recebe a instalacao
  --dry-run     nao altera nada; so imprime o que seria feito
  --json        saida em JSON
  --help,-h     esta ajuda

O conjunto apagado e CALCULADO, nunca adivinhado:
  1. .claude/mosk/ inteiro (tasks, templates, scripts, data, checklists, config)
  2. cada skill/agente que o template novo possui (serao substituidos)
  3. orfaos: skills `mosk-*` e agentes `mosk-*` instalados que sumiram upstream

NUNCA tocados: .claude/rules/, .claude/settings.json, .claude/settings.local.json,
docs/, CLAUDE.md, AGENTS.md, .codex/ — e qualquer skill ou agente fora do
conjunto acima (skills proprias do usuario nao sao do MOSK).

Skill/agente sem prefixo `mosk-` que o template novo nao possui e REPORTADO como
"possivelmente orfao" e deixado no disco: a decisao e do usuario.

Exit 0 = ok; 1 = erro de execucao; 2 = erro de uso.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from) FROM="${2:-}"; shift 2 ;;
        --to)   TO="${2:-}";   shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --json) JSON=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "opcao desconhecida: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -z "$FROM" || -z "$TO" ]] && { echo "erro: --from e --to sao obrigatorios" >&2; usage >&2; exit 2; }
[[ -d "$FROM/.claude" ]] || { echo "erro: '$FROM' nao parece o template MOSK (falta .claude/)" >&2; exit 2; }
[[ -d "$TO" ]] || { echo "erro: destino '$TO' nao existe" >&2; exit 2; }

FROM="$(cd "$FROM" && pwd)"
TO="$(cd "$TO" && pwd)"

# Guarda de sanidade: apagar a origem seria catastrofico e o erro e facil de
# cometer (`--from . --to .`).
[[ "$FROM" == "$TO" ]] && { echo "erro: --from e --to apontam para o mesmo diretorio" >&2; exit 2; }

REPLACED=()   # substituidos pelo template novo
ORPHANS=()    # do namespace mosk-, sumiram upstream -> removidos
AMBIGUOUS=()  # fora do namespace, sumiram upstream -> reportados, NAO removidos
PRESERVED=()  # protegidos explicitamente

# ---------- 1. .claude/mosk/ inteiro ----------
[[ -d "$TO/.claude/mosk" ]] && REPLACED+=(".claude/mosk/")

# ---------- 2. o que o template novo possui ----------
new_skills=()
if [[ -d "$FROM/.claude/skills" ]]; then
    for d in "$FROM/.claude/skills"/*/; do
        [[ -d "$d" ]] || continue
        n="$(basename "$d")"
        new_skills+=("$n")
        [[ -e "$TO/.claude/skills/$n" ]] && REPLACED+=(".claude/skills/$n/")
    done
fi

new_agents=()
if [[ -d "$FROM/.claude/agents" ]]; then
    for f in "$FROM/.claude/agents"/*.md; do
        [[ -f "$f" ]] || continue
        n="$(basename "$f")"
        new_agents+=("$n")
        [[ -e "$TO/.claude/agents/$n" ]] && REPLACED+=(".claude/agents/$n")
    done
fi

in_list() {  # in_list <needle> <haystack...>
    local needle="$1"; shift
    local x
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

# ---------- 3. orfaos ----------
if [[ -d "$TO/.claude/skills" ]]; then
    for d in "$TO/.claude/skills"/*/; do
        [[ -d "$d" ]] || continue
        n="$(basename "$d")"
        in_list "$n" "${new_skills[@]+"${new_skills[@]}"}" && continue
        if [[ "$n" == mosk-* ]]; then
            ORPHANS+=(".claude/skills/$n/")
        else
            AMBIGUOUS+=(".claude/skills/$n/")
        fi
    done
fi

if [[ -d "$TO/.claude/agents" ]]; then
    for f in "$TO/.claude/agents"/*.md; do
        [[ -f "$f" ]] || continue
        n="$(basename "$f")"
        in_list "$n" "${new_agents[@]+"${new_agents[@]}"}" && continue
        if [[ "$n" == mosk-* ]]; then
            ORPHANS+=(".claude/agents/$n")
        else
            AMBIGUOUS+=(".claude/agents/$n")
        fi
    done
fi

# ---------- protegidos ----------
for p in ".claude/rules" ".claude/settings.json" ".claude/settings.local.json" \
         "docs" "CLAUDE.md" "AGENTS.md" ".codex"; do
    [[ -e "$TO/$p" ]] && PRESERVED+=("$p")
done

# ---------- relatorio ----------
emit_human() {
    echo "reset-install: $FROM -> $TO"
    [[ "$DRY_RUN" -eq 1 ]] && echo "(dry-run: nada foi alterado)"
    echo
    echo "substituidos (${#REPLACED[@]}):"
    for x in "${REPLACED[@]+"${REPLACED[@]}"}"; do echo "  ~ $x"; done
    [[ ${#REPLACED[@]} -eq 0 ]] && echo "  (nenhum — instalacao nova)"
    echo
    echo "orfaos removidos (${#ORPHANS[@]}):"
    for x in "${ORPHANS[@]+"${ORPHANS[@]}"}"; do echo "  - $x"; done
    [[ ${#ORPHANS[@]} -eq 0 ]] && echo "  (nenhum)"
    echo
    echo "preservados (${#PRESERVED[@]}):"
    for x in "${PRESERVED[@]+"${PRESERVED[@]}"}"; do echo "  = $x"; done
    if [[ ${#AMBIGUOUS[@]} -gt 0 ]]; then
        echo
        echo "possivelmente orfaos — NAO removidos, decida voce (${#AMBIGUOUS[@]}):"
        for x in "${AMBIGUOUS[@]+"${AMBIGUOUS[@]}"}"; do echo "  ? $x"; done
        echo "  (fora do namespace mosk-; se forem seus, ignore)"
    fi
}

json_arr() {
    local first=1 x
    printf '['
    for x in "$@"; do
        [[ $first -eq 0 ]] && printf ','
        printf '"%s"' "$x"
        first=0
    done
    printf ']'
}

emit_json() {
    printf '{"from":"%s","to":"%s","dry_run":%s,"replaced":' "$FROM" "$TO" "$([[ $DRY_RUN -eq 1 ]] && echo true || echo false)"
    json_arr "${REPLACED[@]+"${REPLACED[@]}"}"
    printf ',"orphans_removed":'
    json_arr "${ORPHANS[@]+"${ORPHANS[@]}"}"
    printf ',"preserved":'
    json_arr "${PRESERVED[@]+"${PRESERVED[@]}"}"
    printf ',"ambiguous":'
    json_arr "${AMBIGUOUS[@]+"${AMBIGUOUS[@]}"}"
    printf '}\n'
}

if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ "$JSON" -eq 1 ]] && emit_json || emit_human
    exit 0
fi

# ---------- execucao ----------
for x in "${REPLACED[@]+"${REPLACED[@]}"}" "${ORPHANS[@]+"${ORPHANS[@]}"}"; do
    rm -rf "${TO:?}/${x%/}"
done

# Instala o template novo por cima. `cp -R "$FROM/.claude/."` copia o CONTEUDO
# de .claude/, preservando o que ja existe la e nao veio do template (rules/,
# settings.json) — que e exatamente o contrato de "preservados" acima.
mkdir -p "$TO/.claude"
cp -R "$FROM/.claude/." "$TO/.claude/"

[[ "$JSON" -eq 1 ]] && emit_json || emit_human
exit 0
