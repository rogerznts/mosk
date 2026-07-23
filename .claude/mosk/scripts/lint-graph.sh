#!/usr/bin/env bash
# lint-graph.sh — valida a FORMA do pipeline-graph.yaml (ADR-0007).
#
# Regra invariante: todo registro (nó, aresta, escalação, guard) cabe em UMA
# linha em flow style ({ ... }). Blocos multi-linha quebram o parser awk das
# projeções em common.sh sem erro visível — este lint pega isso cedo.
#
# Usage: lint-graph.sh [--quiet] [--help]
# Exit 0 = forma ok; exit 1 = violações listadas (path:line :: detalhe).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

QUIET=0
for arg in "$@"; do
    case "$arg" in
        --help|-h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --quiet) QUIET=1 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

GF="$(graph_file)"
if [[ ! -f "$GF" ]]; then
    echo "erro: pipeline-graph.yaml não encontrado em $GF" >&2
    exit 2
fi

violations="$(
    awk '
        # bloco atual (chave top-level sem indentação)
        /^[^[:space:]#]/ {
            block = ""
            if ($0 ~ /^nodes:/)        block = "nodes"
            else if ($0 ~ /^edges:/)   block = "edges"
            else if ($0 ~ /^escalations:/) block = "escalations"
            else if ($0 ~ /^guards:/)  block = "guards"
            next
        }
        # ignora linhas em branco e comentários
        /^[[:space:]]*($|#)/ { next }

        block == "edges" || block == "escalations" {
            # deve ser um item de lista com flow map fechado na mesma linha
            if ($0 !~ /^[[:space:]]*-[[:space:]]*\{.*\}[[:space:]]*$/)
                printf "%d :: %s :: item de %s deve ser \"- { ... }\" em uma linha\n", NR, block, block
        }
        block == "nodes" || block == "guards" {
            # deve ser "  chave: { ... }" fechado na mesma linha
            if ($0 !~ /^[[:space:]]+[A-Za-z0-9_-]+[[:space:]]*:[[:space:]]*\{.*\}[[:space:]]*$/)
                printf "%d :: %s :: entrada de %s deve ser \"chave: { ... }\" em uma linha\n", NR, block, block
        }
    ' "$GF"
)"

if [[ -z "$violations" ]]; then
    [[ "$QUIET" -eq 1 ]] || echo "clean ✓ (forma do pipeline-graph.yaml ok)"
    exit 0
fi

echo "$violations" | while IFS= read -r v; do
    echo "$GF:$v"
done
exit 1
