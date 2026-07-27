#!/usr/bin/env bash
# sync-hallmark.sh — re-sincroniza o vendor do Hallmark em .claude/mosk/data/hallmark.
#
# O vendor é um FORK: além da cópia do upstream, carrega as adequações MOSK
# (bloco "## MOSK integration", tokens.css trazido de fora da skill, links
# reescritos, SKILL.md renomeado). Rodar `npx degit` na mão apaga tudo isso.
#
# Como funciona: baixa o upstream no ref ANTIGO, tira um diff contra o vendor
# atual (= exatamente as adequações MOSK), baixa o upstream no ref NOVO e
# reaplica esse diff. Conflito vira .rej e o vendor NÃO é trocado.
#
# Usage: sync-hallmark.sh [--ref <sha|tag|branch>] [--dry-run] [--help]
#   --ref      novo ref do upstream (default: o ref pinado no VENDOR.md = no-op)
#   --dry-run  baixa, aplica e valida em area temporaria; nao troca o vendor
#
# Exit 0 = ok; 1 = conflito de patch ou link quebrado (vendor intacto).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VENDOR_DIR="$INSTALL_ROOT/.claude/mosk/data/hallmark"
UPSTREAM="Nutlope/hallmark"
SKILL_PATH="skills/hallmark"

NEW_REF=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --ref) NEW_REF="${2:-}"; [[ -n "$NEW_REF" ]] || { echo "erro: --ref exige um valor" >&2; exit 2; }; shift ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
    esac
    shift
done

for bin in curl git tar; do
    command -v "$bin" >/dev/null 2>&1 || { echo "erro: $bin nao encontrado" >&2; exit 2; }
done
[[ -f "$VENDOR_DIR/VENDOR.md" ]] || { echo "erro: $VENDOR_DIR/VENDOR.md nao encontrado" >&2; exit 2; }
# no repo de desenvolvimento do MOSK o espelho da raiz aponta para o template
# por symlink; trocar o vendor dali transformaria o link em copia duplicada.
if [[ -L "$VENDOR_DIR" ]]; then
    echo "erro: $VENDOR_DIR e um symlink para $(readlink "$VENDOR_DIR")" >&2
    echo "      rode o script que fica ao lado do vendor real." >&2
    exit 2
fi

read_pinned_ref() {
    sed -n 's/^| Pinned ref | `\([a-zA-Z0-9._-]\{4,40\}\)`.*/\1/p' "$VENDOR_DIR/VENDOR.md" | head -1
}
OLD_REF="$(read_pinned_ref)"
[[ -n "$OLD_REF" ]] || { echo "erro: nao consegui ler o ref pinado do VENDOR.md" >&2; exit 2; }
NEW_REF="${NEW_REF:-$OLD_REF}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "ref atual: $OLD_REF"
echo "ref novo:  $NEW_REF"
echo "vendor:    $VENDOR_DIR"
echo

# fetch <ref> <destino> — a skill do upstream + os dois arquivos que vivem fora
# dela (tokens.css dos 20 temas e a licenca MIT). Tarball em vez de degit: o
# codeload aceita qualquer SHA, inclusive commits que nao sao ponta de branch.
fetch() {
    local ref="$1" dest="$2"
    local box="$TMP/tar-$ref"
    if [[ ! -d "$box" ]]; then
        mkdir -p "$box"
        curl -sfL "https://codeload.github.com/$UPSTREAM/tar.gz/$ref" | tar -xz -C "$box" \
            || { echo "erro: nao consegui baixar $UPSTREAM@$ref (ref inexistente?)" >&2; exit 2; }
    fi
    local root
    root="$(find "$box" -maxdepth 1 -mindepth 1 -type d | head -1)"
    [[ -d "$root/$SKILL_PATH" ]] || { echo "erro: $SKILL_PATH ausente em $UPSTREAM@$ref" >&2; exit 2; }
    rm -rf "$dest"
    cp -R "$root/$SKILL_PATH" "$dest"
    cp "$root/site/css/tokens.css" "$dest/references/themes/tokens.css"
    cp "$root/LICENSE" "$dest/LICENSE"
    [[ -f "$dest/SKILL.md" ]] || { echo "erro: SKILL.md ausente em $UPSTREAM@$ref" >&2; exit 2; }
}

# em caso de falha, preserva a area de trabalho para o usuario resolver os .rej
KEEP_DIR="${TMPDIR:-/tmp}/mosk-hallmark-sync"
keep_workdir() {
    rm -rf "$KEEP_DIR"
    mkdir -p "$KEEP_DIR"
    cp -R "$TMP/new" "$KEEP_DIR/new" 2>/dev/null || true
    cp "$TMP/mosk.patch" "$KEEP_DIR/mosk.patch" 2>/dev/null || true
    echo >&2
    echo "area de trabalho preservada em: $KEEP_DIR" >&2
    echo "  new/        o upstream $NEW_REF com as adequacoes que aplicaram" >&2
    echo "  new/**.rej  o que faltou aplicar" >&2
    echo "  mosk.patch  o diff completo das adequacoes MOSK" >&2
    echo "Depois de resolver: copie new/ sobre $VENDOR_DIR e atualize o VENDOR.md." >&2
}

cd "$TMP"
fetch "$OLD_REF" "$TMP/old"
echo "baixado ref antigo: $(find "$TMP/old" -type f | wc -l | tr -d ' ') arquivos"
if [[ "$NEW_REF" == "$OLD_REF" ]]; then
    cp -R "$TMP/old" "$TMP/new"
else
    fetch "$NEW_REF" "$TMP/new"
    echo "baixado ref novo:   $(find "$TMP/new" -type f | wc -l | tr -d ' ') arquivos"
fi
cp -R "$VENDOR_DIR" "$TMP/cur"

# --- diff old -> cur = as adequacoes MOSK -----------------------------------
git diff --no-index --no-color -M --text old cur > "$TMP/mosk.patch" || true
if [[ ! -s "$TMP/mosk.patch" ]]; then
    echo "aviso: nenhuma adequacao MOSK detectada (vendor identico ao upstream?)" >&2
else
    echo "adequacoes MOSK:    $(grep -c '^diff --git' "$TMP/mosk.patch" || true) arquivo(s), $(wc -l < "$TMP/mosk.patch" | tr -d ' ') linhas de patch"
fi

# --- reaplicar no ref novo --------------------------------------------------
rejects=0
if [[ -s "$TMP/mosk.patch" ]]; then
    # -p2: `git diff --no-index old cur` gera paths `a/old/x` e `b/cur/x`;
    # sao dois componentes a remover, nao um.
    if ! (cd "$TMP/new" && git apply -p2 --reject --whitespace=nowarn "$TMP/mosk.patch" >/dev/null 2>"$TMP/apply.err"); then
        rejects="$(find "$TMP/new" -name '*.rej' | wc -l | tr -d ' ')"
        echo
        echo "CONFLITO ao reaplicar as adequacoes MOSK no ref $NEW_REF:" >&2
        sed 's/^/  /' "$TMP/apply.err" >&2
        find "$TMP/new" -name '*.rej' | sed "s|$TMP/new/|  rejeitado: |" >&2
        echo >&2
        echo "O upstream mudou os trechos que o MOSK adapta ($rejects arquivo(s) com .rej)." >&2
        keep_workdir
        exit 1
    fi
    echo "patch aplicado:     limpo"
fi

# ref pinado no VENDOR.md
if [[ -f "$TMP/new/VENDOR.md" && "$NEW_REF" != "$OLD_REF" ]]; then
    sed -i '' "s#\`$OLD_REF\`#\`$NEW_REF\`#g" "$TMP/new/VENDOR.md"
    echo "VENDOR.md:          ref atualizado para $NEW_REF (revise a data e a lista de modificacoes)"
fi

# --- validacao de links -----------------------------------------------------
broken=0
while IFS= read -r f; do
    d="$(dirname "$f")"
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        case "$link" in http*|mailto:*|\#*) continue ;; esac
        target="${link%%#*}"; [[ -z "$target" ]] && continue
        [[ -e "$d/$target" ]] || { broken=$((broken + 1)); echo "LINK QUEBRADO  ${f#"$TMP"/new/} -> $link" >&2; }
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed 's/^](//; s/)$//')
done < <(find "$TMP/new" -name '*.md')

# --- invariantes do vendor --------------------------------------------------
for marker in MOSK-HEADER MOSK-INTEGRATION; do
    grep -q "<!-- $marker:BEGIN" "$TMP/new/hallmark.md" 2>/dev/null \
        || { echo "INVARIANTE  bloco $marker ausente no hallmark.md resultante" >&2; broken=$((broken + 1)); }
done
[[ -f "$TMP/new/references/themes/tokens.css" ]] \
    || { echo "INVARIANTE  references/themes/tokens.css ausente" >&2; broken=$((broken + 1)); }
[[ -f "$TMP/new/LICENSE" ]] \
    || { echo "INVARIANTE  LICENSE ausente (MIT do upstream)" >&2; broken=$((broken + 1)); }
[[ ! -f "$TMP/new/SKILL.md" ]] \
    || { echo "INVARIANTE  SKILL.md deveria ter virado hallmark.md" >&2; broken=$((broken + 1)); }

echo "links internos ok:  $([[ "$broken" -eq 0 ]] && echo sim || echo "NAO ($broken problema(s))")"

if [[ "$broken" -gt 0 ]]; then
    echo "vendor NAO trocado." >&2
    keep_workdir
    exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    echo "dry-run — mudancas que seriam aplicadas:"
    diff -rq "$VENDOR_DIR" "$TMP/new" 2>/dev/null | sed 's/^/  /' | head -40 || echo "  (nenhuma)"
    exit 0
fi

rm -rf "$VENDOR_DIR"
cp -R "$TMP/new" "$VENDOR_DIR"
echo "vendor sincronizado: $(find "$VENDOR_DIR" -type f | wc -l | tr -d ' ') arquivos no ref $NEW_REF"
