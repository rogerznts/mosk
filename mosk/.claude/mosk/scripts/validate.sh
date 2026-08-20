#!/usr/bin/env bash
# validate.sh — verificador único do MOSK.
#
# Funde `check-ship-ready.sh`, `check-prerequisites.sh`, `doctor.sh` e
# `audit-docs-paths.sh`. Exit 0 = válido; 1 = violações; 2 = erro de uso.
#
# --- Como este script lê dados, e por quê é diferente do que veio antes ------
#
# O ADR-0021 §3 diz que script não lê dado estruturado: quem lê é o agente, que
# tem um parser de verdade, e passa o valor por argumento. Este script é a
# exceção declarada, porque roda no caso 3 da lista fechada — hook e CI, fora
# da sessão do agente. Não há a quem pedir.
#
# A exceção é estreita, e a estreiteza é o ponto:
#
#   1. Lê no máximo os campos escalares listados em CAMPOS_LIDOS, nada mais.
#   2. Cada campo tem DOMÍNIO FECHADO e é casado por padrão ancorado.
#   3. O que não casa exatamente é RECUSADO — nunca interpretado, nunca
#      desempacotado. `gate: {x}` não vira nada: simplesmente não é `PASS`.
#   4. NUNCA lê prosa. `status_reason`, `finding` e afins não são legíveis aqui.
#
# É a decisão 1 do ADR-0020 — validar o domínio da chave, não a forma do valor
# — que aquele ADR mediu e considerou permanentemente correta. O que se abandona
# é a decisão 5/6 dele: a tentativa de reconhecer e recusar toda forma exótica
# do YAML. Aqui não há o que reconhecer, porque só se aceita a forma exata.
#
# CONSTANTES ESPELHADAS: os domínios abaixo espelham `../pipeline.yaml`, que é
# a fonte. `validate.sh self-check` confere a sincronia quando há um parser
# YAML disponível, e avisa (sem falhar) quando não há — FR-007 proíbe exigir
# PyYAML, npm ou pip.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

PIPELINE_YAML="$SCRIPT_DIR/../pipeline.yaml"

# --- domínios espelhados de pipeline.yaml -----------------------------------
FASES="specify plan tasks implement qa-gate archived"
VEREDITOS="PASS CONCERNS FAIL WAIVED"
VEREDITOS_QUE_CONCLUEM="PASS WAIVED"
STATUS_VALIDOS="active archived"
MARCADOR_BLOQUEANTE='[NEEDS CLARIFICATION'
PADRAO_TASK_ABERTA='^- \[ \] T[0-9]{3}'
TS_UTC='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

# Campos escalares que este script tem permissão de ler. Qualquer outro é erro
# de uso — pedir prosa a um leitor de shell não é uma leitura truncada, é um bug.
CAMPOS_LIDOS="current_phase status spec_id branch gate waiver_active waiver_approved_by waiver_approved_at"

usage() {
    cat <<'EOF'
validate.sh <subcomando> [opções]

Subcomandos:
  ship-ready       spec do branch está fechada e pronta para merge (default)
  prerequisites    artefatos exigidos por uma fase existem
  install          integridade da instalação do toolkit
  docs-paths       saídas declaradas ficam sob os domínios canônicos de docs/
  self-check       constantes deste script batem com pipeline.yaml
  fixtures         fixtures de contrato (autoteste)
  all              todos os acima

Opções:
  --spec <locator>  spec alvo (número, spec_id ou branch)
  --for <fase>      fase a verificar em `prerequisites`
  --json            saída em JSON
  --help, -h        esta ajuda

Exit: 0 válido · 1 violações · 2 erro de uso.

Quem invoca (ADR-0021 §5 — verificação sem chamador nomeado não conta):
  - hook de `gh pr merge`  -> ship-ready
  - CI / branch protection -> ship-ready
  - `/mosk-dev` antes do PR -> ship-ready
  - tasks de fase           -> prerequisites
  - `/mosk-update`, release -> install
EOF
}

# --- leitor de campo escalar, fail-closed -----------------------------------
# Lê UMA chave de domínio fechado. Aceita apenas a forma canônica que o toolkit
# emite: `chave: valor` ou `chave: "valor"`, uma linha, sem continuação.
# Qualquer outra coisa devolve string vazia — que os chamadores tratam como
# recusa, nunca como ausência benigna.
ler_campo() {
    local arquivo="$1" chave="$2"
    case " $CAMPOS_LIDOS " in
        *" $chave "*) ;;
        *) echo "erro de uso: '$chave' não está em CAMPOS_LIDOS" >&2; return 2 ;;
    esac
    [[ -f "$arquivo" ]] || return 0
    # Âncora no início da linha; valor sem aspas ou entre aspas duplas que
    # abrem e fecham na mesma linha. Múltiplas ocorrências => recusa.
    local n
    n="$(grep -cE "^${chave}:[[:space:]]" "$arquivo" 2>/dev/null || true)"
    [[ "$n" == "1" ]] || return 0
    # ALLOWLIST, não blocklist. O valor sem aspas precisa ser inteiramente
    # composto de [A-Za-z0-9._/:-] começando por alfanumérico — o formato de
    # toda enum, booleano, timestamp, spec_id e branch que este script lê.
    # `|`, `>`, `{`, `[`, `'` e `"` ficam de fora por construção, não por
    # enumeração: é a lição do ADR-0020, onde a blocklist errou por omissão.
    sed -nE "s/^${chave}:[[:space:]]+\"([A-Za-z0-9][A-Za-z0-9._\/:-]*)\"[[:space:]]*$/\1/p; s/^${chave}:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._\/:-]*)[[:space:]]*$/\1/p" "$arquivo" | head -1
}

em_dominio() {
    local valor="$1"; shift
    local v
    for v in $@; do [[ "$valor" == "$v" ]] && return 0; done
    return 1
}

# --- acumulador -------------------------------------------------------------
FALHAS=()
falha() { FALHAS+=("$1"); }
SPEC_ID=""; FASE=""

emitir() {
    local rotulo="$1" ok="true"
    [[ ${#FALHAS[@]} -gt 0 ]] && ok="false"
    if [[ "$JSON" -eq 1 ]]; then
        local arr="[" primeiro=1 f
        for f in "${FALHAS[@]:-}"; do
            [[ -n "$f" ]] || continue
            [[ $primeiro -eq 0 ]] && arr+=","
            primeiro=0
            arr+="\"$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        done
        arr+="]"
        printf '{"check":"%s","ok":%s,"spec":"%s","phase":"%s","failures":%s}\n' \
            "$rotulo" "$ok" "$SPEC_ID" "$FASE" "$arr"
    else
        if [[ "$ok" == "true" ]]; then
            echo "$rotulo: OK${SPEC_ID:+ (spec $SPEC_ID)}"
        else
            echo "$rotulo: FALHA${SPEC_ID:+ na spec $SPEC_ID}" >&2
            local f
            for f in "${FALHAS[@]}"; do echo "  ✗ $f" >&2; done
        fi
    fi
    [[ "$ok" == "true" ]]
}

# --- gate: veredito e waiver ------------------------------------------------
checar_gate_conclui() {
    local dir="$1" arquivo="$dir/gate.yaml"
    if [[ ! -f "$arquivo" ]]; then
        falha "gate.yaml ausente — archived sozinho não é evidência de decisão de QA"
        return
    fi
    local veredito; veredito="$(ler_campo "$arquivo" gate)"
    if ! em_dominio "$veredito" $VEREDITOS; then
        falha "veredito de gate inválido ou ilegível: '${veredito}'"
        return
    fi
    if ! em_dominio "$veredito" $VEREDITOS_QUE_CONCLUEM; then
        falha "gate $veredito bloqueia conclusão; corrija ou formalize um WAIVED"
        return
    fi
    [[ "$veredito" == "WAIVED" ]] || return 0
    # WAIVED formalizado: dono, motivo e data. Sem os quatro, é um FAIL sem registro.
    local ativo aprovador em
    ativo="$(ler_campo "$arquivo" waiver_active)"
    aprovador="$(ler_campo "$arquivo" waiver_approved_by)"
    em="$(ler_campo "$arquivo" waiver_approved_at)"
    [[ "$ativo" == "true" ]] || falha "WAIVED sem waiver_active: true"
    [[ -n "$aprovador" ]] || falha "WAIVED sem waiver_approved_by"
    [[ "$em" =~ $TS_UTC ]] || falha "WAIVED sem waiver_approved_at em ISO 8601 UTC"
    # waiver_reason é prosa: confere-se que a linha existe com conteúdo, sem lê-la.
    grep -qE '^waiver_reason:[[:space:]]+[^[:space:]"]|^waiver_reason:[[:space:]]+"[^"]+"' "$arquivo" \
        || falha "WAIVED sem waiver_reason"
}

# --- promoções --------------------------------------------------------------
checar_promocoes() {
    local repo="$1" dir="$2" arquivo alvo modo resolvido
    while IFS= read -r arquivo; do
        [[ -n "$arquivo" ]] || continue
        grep -q '^promote:' "$arquivo" 2>/dev/null || continue
        alvo="$(sed -nE 's/^promote:[[:space:]]+"?([^"]*)"?[[:space:]]*$/\1/p' "$arquivo" | head -1)"
        modo="$(sed -nE 's/^promote_mode:[[:space:]]+"?([a-z]*)"?[[:space:]]*$/\1/p' "$arquivo" | head -1)"
        [[ -n "$modo" ]] || modo=copy
        if ! em_dominio "$modo" copy append manual; then
            falha "promote_mode inválido em $(basename "$arquivo"): '$modo'"; continue
        fi
        if ! resolvido="$(validate_promotion_target "$repo" "$alvo" "$modo" 2>&1)"; then
            falha "promote inválido em $(basename "$arquivo"): $resolvido"; continue
        fi
        [[ "$modo" == manual ]] && continue
        if [[ ! -f "$resolvido" ]]; then
            falha "promote não aplicado: $(basename "$arquivo") -> $alvo"; continue
        fi
        if [[ "$modo" == copy ]] && ! cmp -s "$arquivo" "$resolvido"; then
            falha "promote copy divergente: $(basename "$arquivo") -> $alvo"
        fi
    done < <(find "$dir" -type f -name '*.md' -print 2>/dev/null)
}

# --- subcomando: ship-ready -------------------------------------------------
cmd_ship_ready() {
    local repo branch dir prefixo
    repo="$(get_repo_root)"; branch="$(get_current_branch)"
    if [[ ! "$branch" =~ ^([a-z][a-z-]*/)?([0-9]{3})- ]]; then
        SPEC_ID=""; FASE=""
        emitir "ship-ready"; return $?
    fi
    prefixo="${BASH_REMATCH[2]}"; SPEC_ID="$prefixo"
    if ! dir="$(resolve_spec_dir "$repo" "$branch" any 2>&1)"; then
        falha "falha ao resolver spec do branch '$branch': $dir"
        emitir "ship-ready"; return $?
    fi
    [[ -f "$dir/spec-meta.yaml" ]] || { falha "spec-meta.yaml ausente em $dir"; emitir "ship-ready"; return $?; }

    SPEC_ID="$(ler_campo "$dir/spec-meta.yaml" spec_id)"
    FASE="$(ler_campo "$dir/spec-meta.yaml" current_phase)"
    local status; status="$(ler_campo "$dir/spec-meta.yaml" status)"

    em_dominio "$FASE" $FASES || falha "current_phase inválido ou ilegível: '$FASE'"
    em_dominio "$status" $STATUS_VALIDOS || falha "status inválido ou ilegível: '$status'"
    [[ "$FASE" == "archived" ]] || falha "current_phase='$FASE' (esperado 'archived'; a spec não passou pelo archive)"
    [[ "$status" == "archived" || "$FASE" != "archived" ]] || falha "status e current_phase divergem"

    checar_gate_conclui "$dir"
    checar_promocoes "$repo" "$dir"
    if has_git && [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
        falha "working tree sujo (mudanças não commitadas)"
    fi
    emitir "ship-ready"
}

# --- subcomando: prerequisites ----------------------------------------------
cmd_prerequisites() {
    local repo dir destino="$FOR_PHASE"
    repo="$(get_repo_root)"
    [[ -n "$destino" ]] || { echo "prerequisites exige --for <fase>" >&2; exit 2; }
    em_dominio "$destino" $FASES || { echo "fase desconhecida: $destino" >&2; exit 2; }
    if ! dir="$(resolve_spec_dir "$repo" "${SPEC_LOCATOR:-$(get_current_branch)}" any 2>&1)"; then
        falha "falha ao resolver spec: $dir"; emitir "prerequisites"; return $?
    fi
    SPEC_ID="$(ler_campo "$dir/spec-meta.yaml" spec_id)"
    FASE="$destino"

    local sempre="spec.md"
    case "$destino" in
        tasks|implement|qa-gate|archived) sempre="spec.md plan.md" ;;
    esac
    case "$destino" in
        implement|qa-gate|archived) sempre="spec.md plan.md tasks.md" ;;
    esac
    local a
    for a in $sempre; do
        [[ -s "$dir/$a" ]] || { falha "$a ausente ou vazio"; continue; }
        grep -qF "$MARCADOR_BLOQUEANTE" "$dir/$a" 2>/dev/null \
            && falha "$a ainda contém esclarecimento bloqueante"
    done
    case "$destino" in
        qa-gate|archived)
            grep -qE "$PADRAO_TASK_ABERTA" "$dir/tasks.md" 2>/dev/null \
                && falha "tasks.md possui tarefas abertas"
            ;;
    esac
    [[ "$destino" == "archived" ]] && { checar_gate_conclui "$dir"; checar_promocoes "$repo" "$dir"; }
    emitir "prerequisites"
}

# --- subcomando: install ----------------------------------------------------
cmd_install() {
    # SCRIPT_DIR = <root>/.claude/mosk/scripts  ->  ../..  = <root>/.claude
    local raiz="$SCRIPT_DIR/../.." s
    for s in "$SCRIPT_DIR"/*.sh; do
        bash -n "$s" 2>/dev/null || falha "erro de sintaxe em $(basename "$s")"
    done
    [[ -f "$PIPELINE_YAML" ]] || falha "pipeline.yaml ausente — a regra do pipeline não tem fonte"
    local obrigatorio
    for obrigatorio in "$SCRIPT_DIR/../core-config.yaml" "$SCRIPT_DIR/../pipeline.yaml"; do
        [[ -f "$obrigatorio" ]] || falha "arquivo obrigatório ausente: $(basename "$obrigatorio")"
    done
    local n_agentes
    n_agentes="$(find "$raiz/agents" -maxdepth 1 -name 'mosk-*.md' 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$n_agentes" -ge 1 ]] || falha "nenhum agente encontrado em .claude/agents/"
    SPEC_ID=""; FASE=""
    emitir "install"
}

# --- subcomando: self-check -------------------------------------------------
# Confere as constantes espelhadas contra o pipeline.yaml. Precisa de um parser
# YAML; sem ele, AVISA e passa — FR-007 proíbe exigir PyYAML/npm/pip.
cmd_self_check() {
    SPEC_ID=""; FASE=""
    if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
        echo "self-check: PULADO (sem parser YAML disponível — não é dependência obrigatória)" >&2
        emitir "self-check"; return $?
    fi
    local saida
    saida="$(python3 - "$PIPELINE_YAML" "$FASES" "$VEREDITOS" "$VEREDITOS_QUE_CONCLUEM" <<'PY'
import sys, yaml
p, fases, vereditos, conclui = sys.argv[1:5]
d = yaml.safe_load(open(p))
erros = []
if list(d['phases'].keys()) != fases.split():
    erros.append(f"FASES divergem: script={fases.split()} yaml={list(d['phases'].keys())}")
if d['gate']['verdicts'] != vereditos.split():
    erros.append(f"VEREDITOS divergem: script={vereditos.split()} yaml={d['gate']['verdicts']}")
ok_yaml = sorted(k for k, v in d['gate']['allows_completion'].items() if v is not False)
if ok_yaml != sorted(conclui.split()):
    erros.append(f"VEREDITOS_QUE_CONCLUEM divergem: script={sorted(conclui.split())} yaml={ok_yaml}")
print("\n".join(erros))
PY
)" || { falha "self-check não pôde rodar"; emitir "self-check"; return $?; }
    [[ -z "$saida" ]] || while IFS= read -r l; do [[ -n "$l" ]] && falha "$l"; done <<< "$saida"
    emitir "self-check"
}

# --- subcomando: fixtures ---------------------------------------------------
cmd_fixtures() {
    SPEC_ID=""; FASE=""
    local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/mosk-validate-fx.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    local passou=0 total=0
    caso() {
        total=$((total + 1))
        local nome="$1" esperado="$2"; shift 2
        local obtido; obtido="$("$@" 2>/dev/null || true)"
        if [[ "$obtido" == "$esperado" ]]; then passou=$((passou + 1))
        else falha "fixture '$nome' :: esperado '$esperado' :: obtido '$obtido'"; fi
    }
    local g="$tmp/gate.yaml"

    printf 'gate: "PASS"\n' > "$g"
    caso "gate PASS entre aspas" "PASS" ler_campo "$g" gate
    printf 'gate: PASS\n' > "$g"
    caso "gate PASS sem aspas" "PASS" ler_campo "$g" gate

    # Fail-closed: as formas que o ADR-0020 levou treze voltas para recusar.
    printf 'gate: {x: PASS}\n' > "$g"
    caso "coleção inline recusada" "" ler_campo "$g" gate
    printf 'gate: |\n  PASS\n' > "$g"
    caso "escalar em bloco recusado" "" ler_campo "$g" gate
    printf 'gate: PASS\ngate: FAIL\n' > "$g"
    caso "chave duplicada recusada" "" ler_campo "$g" gate
    printf '  gate: PASS\n' > "$g"
    caso "chave indentada recusada" "" ler_campo "$g" gate
    printf 'gate: PASS # comentário\n' > "$g"
    caso "comentário na linha recusado" "" ler_campo "$g" gate
    printf 'not_gate: PASS\n' > "$g"
    caso "chave diferente não casa" "" ler_campo "$g" gate

    # Domínio fechado: o que não é veredito não passa, seja qual for a forma.
    em_dominio "PASS" $VEREDITOS && caso "PASS em domínio" "" true
    if em_dominio "{x}" $VEREDITOS; then falha "fixture 'valor fabricado fora do domínio' :: aceitou '{x}'"; fi
    total=$((total + 1)); passou=$((passou + 1))

    # T018 — regressão da spec 014: mesclada em qa-gate, sem archive.
    local sd="$tmp/014-feature-x"; mkdir -p "$sd"
    printf 'spec_id: "014-feature-x"\nstatus: active\ncurrent_phase: qa-gate\n' > "$sd/spec-meta.yaml"
    local fase; fase="$(ler_campo "$sd/spec-meta.yaml" current_phase)"
    total=$((total + 1))
    if [[ "$fase" == "qa-gate" ]]; then passou=$((passou + 1))
    else falha "fixture '014: fase lida' :: esperado 'qa-gate' :: obtido '$fase'"; fi
    total=$((total + 1))
    if [[ "$fase" != "archived" ]]; then passou=$((passou + 1))
    else falha "fixture '014: qa-gate deve reprovar ship-ready' :: passou indevidamente"; fi

    # Guardrail: o hook precisa distinguir INVOCAÇÃO de MENÇÃO. Os dois casos
    # abaixo são falsos positivos reais — o hook bloqueou a si mesmo ao editar
    # um heredoc que citava o comando, e depois ao escrever a mensagem de
    # commit que o descrevia.
    local hook="$SCRIPT_DIR/../../hooks/guard-spec-merge.sh"
    if [[ -f "$hook" ]] && command -v python3 >/dev/null 2>&1; then
        hook_rc() {
            printf '%s' "$1" | bash "$hook" >/dev/null 2>&1 && echo 0 || echo $?
        }
        local j_mencao j_heredoc
        j_mencao='{"tool_input":{"command":"echo rode g''h p''r me''rge depois"}}'
        j_heredoc='{"tool_input":{"command":"cat <<EOF\ng''h p''r me''rge 1\nEOF"}}'
        total=$((total + 2))
        [[ "$(hook_rc "$j_mencao")" == "0" ]] && passou=$((passou + 1)) \
            || falha "fixture 'hook ignora menção' :: bloqueou indevidamente"
        [[ "$(hook_rc "$j_heredoc")" == "0" ]] && passou=$((passou + 1)) \
            || falha "fixture 'hook ignora heredoc' :: bloqueou indevidamente"
    fi

    [[ ${#FALHAS[@]} -eq 0 ]] && echo "fixtures: $passou/$total"
    emitir "fixtures"
}

# --- subcomando: docs-paths -------------------------------------------------
# Só caminhos DECLARADOS como saída contam. Uma task pode citar `docs/prd.md`
# ao descrever a estrutura legada que ela migra — isso não é uma saída, e
# tratá-lo como tal produz falso positivo (foi o que a primeira versão fez).
cmd_docs_paths() {
    SPEC_ID=""; FASE=""
    local dominios="discovery prd architecture ui qa specs handoff project"
    local introduz='(\*\*Save to:\*\*|Save to:|Save it as|save it as|Create the document as|Write to:|Output to:|Save the populated document to)'
    local origem alvo dom ok d linha
    checar_alvo() {
        local arq="$1" alvo="$2"
        [[ -n "$alvo" ]] || return 0
        dom="${alvo#docs/}"; dom="${dom%%/*}"
        ok=0
        for d in $dominios; do [[ "$dom" == "$d" ]] && ok=1; done
        [[ "$dom" == "index.md" ]] && ok=1
        [[ $ok -eq 1 ]] || falha "$arq :: saída fora dos domínios canônicos -> $alvo"
    }
    # R1: prosa de task que introduz um caminho de saída
    while IFS= read -r linha; do
        [[ -n "$linha" ]] || continue
        origem="$(basename "${linha%%:*}")"
        alvo="$(printf '%s' "$linha" | grep -oE 'docs/[A-Za-z0-9./_-]+\.md' | head -1)"
        checar_alvo "$origem" "$alvo"
    done < <(grep -rnEi "$introduz[[:space:]]*\`?docs/" "$SCRIPT_DIR/../tasks" 2>/dev/null || true)
    # R2/R3: campos estruturais que declaram destino
    while IFS= read -r linha; do
        [[ -n "$linha" ]] || continue
        origem="$(basename "${linha%%:*}")"
        alvo="$(printf '%s' "$linha" | sed -E 's/^.*(filename|docOutputLocation):[[:space:]]*//' | tr -d "'\"" | awk '{print $1}')"
        checar_alvo "$origem" "$alvo"
    done < <(grep -rnE '^[[:space:]]*(filename|docOutputLocation):[[:space:]]*docs/' \
                  "$SCRIPT_DIR/../tasks" "$SCRIPT_DIR/../templates" 2>/dev/null || true)
    emitir "docs-paths"
}

# --- dispatch ---------------------------------------------------------------
JSON=0; SPEC_LOCATOR=""; FOR_PHASE=""; SUB="ship-ready"
[[ $# -gt 0 && "$1" != -* ]] && { SUB="$1"; shift; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON=1 ;;
        --spec) SPEC_LOCATOR="$2"; shift ;;
        --for) FOR_PHASE="$2"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

case "$SUB" in
    ship-ready)    cmd_ship_ready ;;
    prerequisites) cmd_prerequisites ;;
    install)       cmd_install ;;
    docs-paths)    cmd_docs_paths ;;
    self-check)    cmd_self_check ;;
    fixtures)      cmd_fixtures ;;
    all)
        rc=0
        for s in install self-check docs-paths fixtures ship-ready; do
            FALHAS=(); SPEC_ID=""; FASE=""
            "cmd_${s//-/_}" || rc=1
        done
        exit $rc
        ;;
    --help|-h) usage; exit 0 ;;
    *) echo "subcomando desconhecido: $SUB" >&2; usage >&2; exit 2 ;;
esac
