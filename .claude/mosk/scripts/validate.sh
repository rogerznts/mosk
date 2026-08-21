#!/usr/bin/env bash
# validate.sh — verificador único do MOSK.
#
# Funde `check-ship-ready.sh`, `check-prerequisites.sh`, `doctor.sh` e
# `audit-docs-paths.sh`. Exit 0 = válido; 1 = violações; 2 = erro de uso.
#
# --- Como este script lê dados, e por quê é diferente do que veio antes ------
#
# O ADR-0021 §3 diz que script não lê dado estruturado: quem lê é o agente, que
# tem um parser de verdade, e passa o value por argumento. Este script é a
# exceção declarada, porque roda no assert_case 3 da lista fechada — hook e CI, fora
# da sessão do agente. Não há a quem pedir.
#
# A exceção é estreita, e a estreiteza é o ponto:
#
#   1. Lê no máximo os campos escalares listados em READABLE_FIELDS, nada mais.
#   2. Cada campo tem DOMÍNIO FECHADO e é casado por padrão ancorado.
#   3. O que não casa exatamente é RECUSADO — nunca interpretado, nunca
#      desempacotado. `gate: {x}` não vira nada: simplesmente não é `PASS`.
#   4. NUNCA lê prosa. `status_reason`, `finding` e afins não são legíveis aqui.
#
# É a decisão 1 do ADR-0020 — validar o domínio da key, não a forma do value
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
PHASES="specify plan tasks implement qa-gate archived"
VERDICTS="PASS CONCERNS FAIL WAIVED"
VERDICTS_ALLOWING_COMPLETION="PASS WAIVED"
VALID_STATUS="active archived"
# Duplas <phase>:<comando> que confirmam cada target_phase, espelhando
# `phases[].confirmed_by` do pipeline.yaml. O `self-check` confere a sincronia.
CONFIRMED_BY="plan:plan tasks:tasks implement:implement implement:apply-qa-fixes qa-gate:qa-gate archived:archive"
BLOCKING_MARKER='[NEEDS CLARIFICATION'
OPEN_TASK_PATTERN='^- \[ \] T[0-9]{3}'
TS_UTC='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

# Campos escalares que este script tem permissão de ler. Qualquer outro é erro
# de uso — pedir prosa a um leitor de shell não é uma leitura truncada, é um bug.
READABLE_FIELDS="current_phase status spec_id branch gate waiver_active waiver_approved_by waiver_approved_at"

usage() {
    cat <<'EOF'
validate.sh <subcomando> [opções]

Subcomandos:
  ship-ready       spec do branch está fechada e pronta para merge (default)
  prerequisites    artefatos exigidos por uma phase existem
  install          integridade da instalação do toolkit
  docs-paths       saídas declaradas ficam sob os domínios canônicos de docs/
  single-source    redação normativa dos contratos não foi copiada
  tasks-sync       as tasks concordam com as fases e comandos do pipeline.yaml
  self-check       constantes deste script batem com pipeline.yaml
  fixtures         fixtures de contract (autoteste)
  all              todos os acima

Opções:
  --spec <locator>  spec target (número, spec_id ou branch)
  --for <phase>      phase a verificar em `prerequisites`
  --json            saída em JSON
  --help, -h        esta ajuda

Exit: 0 válido · 1 violações · 2 erro de uso.

Quem invoca (ADR-0021 §5 — verificação sem chamador nomeado não conta):
  - hook de `gh pr merge`  -> ship-ready
  - CI / branch protection -> ship-ready
  - `/mosk-dev` antes do PR -> ship-ready
  - tasks de phase           -> prerequisites
  - `/mosk-update`, release -> install
EOF
}

# --- leitor de campo escalar, fail-closed -----------------------------------
# Lê UMA key de domínio fechado. Aceita apenas a forma canônica que o toolkit
# emite: `key: value` ou `key: "value"`, uma line, sem continuação.
# Qualquer outra coisa devolve string vazia — que os chamadores tratam como
# recusa, nunca como ausência benigna.
read_field() {
    local file_path="$1" key="$2"
    case " $READABLE_FIELDS " in
        *" $key "*) ;;
        *) echo "erro de uso: '$key' não está em READABLE_FIELDS" >&2; return 2 ;;
    esac
    [[ -f "$file_path" ]] || return 0
    # Âncora no início da line; value sem aspas ou entre aspas duplas que
    # abrem e fecham na mesma line. Múltiplas ocorrências => recusa.
    local n
    n="$(grep -cE "^${key}:[[:space:]]" "$file_path" 2>/dev/null || true)"
    [[ "$n" == "1" ]] || return 0
    # ALLOWLIST, não blocklist. O value sem aspas precisa ser inteiramente
    # composto de [A-Za-z0-9._/:-] começando por alfanumérico — o formato de
    # toda enum, booleano, timestamp, spec_id e branch que este script lê.
    # `|`, `>`, `{`, `[`, `'` e `"` ficam de fora por construção, não por
    # enumeração: é a lição do ADR-0020, onde a blocklist errou por omissão.
    sed -nE "s/^${key}:[[:space:]]+\"([A-Za-z0-9][A-Za-z0-9._\/:-]*)\"[[:space:]]*$/\1/p; s/^${key}:[[:space:]]+([A-Za-z0-9][A-Za-z0-9._\/:-]*)[[:space:]]*$/\1/p" "$file_path" | head -1
}

in_domain() {
    local value="$1"; shift
    local v
    for v in $@; do [[ "$value" == "$v" ]] && return 0; done
    return 1
}

# --- acumulador -------------------------------------------------------------
FAILURES=()
add_failure() { FAILURES+=("$1"); }
SPEC_ID=""; PHASE=""

emit() {
    local label="$1" ok="true"
    [[ ${#FAILURES[@]} -gt 0 ]] && ok="false"
    if [[ "$JSON" -eq 1 ]]; then
        local arr="[" primeiro=1 f
        for f in "${FAILURES[@]:-}"; do
            [[ -n "$f" ]] || continue
            [[ $primeiro -eq 0 ]] && arr+=","
            primeiro=0
            arr+="\"$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        done
        arr+="]"
        printf '{"check":"%s","ok":%s,"spec":"%s","phase":"%s","failures":%s}\n' \
            "$label" "$ok" "$SPEC_ID" "$PHASE" "$arr"
    else
        if [[ "$ok" == "true" ]]; then
            echo "$label: OK${SPEC_ID:+ (spec $SPEC_ID)}"
        else
            echo "$label: FALHA${SPEC_ID:+ na spec $SPEC_ID}" >&2
            local f
            for f in "${FAILURES[@]}"; do echo "  ✗ $f" >&2; done
        fi
    fi
    [[ "$ok" == "true" ]]
}

# --- gate: verdict e waiver ------------------------------------------------
check_gate_allows_completion() {
    local dir="$1" file_path="$dir/gate.yaml"
    if [[ ! -f "$file_path" ]]; then
        add_failure "gate.yaml ausente — archived sozinho não é evidência de decisão de QA"
        return
    fi
    local verdict; verdict="$(read_field "$file_path" gate)"
    if ! in_domain "$verdict" $VERDICTS; then
        add_failure "verdict de gate inválido ou ilegível: '${verdict}'"
        return
    fi
    if ! in_domain "$verdict" $VERDICTS_ALLOWING_COMPLETION; then
        add_failure "gate $verdict bloqueia conclusão; corrija ou formalize um WAIVED"
        return
    fi
    [[ "$verdict" == "WAIVED" ]] || return 0
    # WAIVED formalizado: dono, motivo e data. Sem os quatro, é um FAIL sem registro.
    local active approver em
    active="$(read_field "$file_path" waiver_active)"
    approver="$(read_field "$file_path" waiver_approved_by)"
    em="$(read_field "$file_path" waiver_approved_at)"
    [[ "$active" == "true" ]] || add_failure "WAIVED sem waiver_active: true"
    [[ -n "$approver" ]] || add_failure "WAIVED sem waiver_approved_by"
    [[ "$em" =~ $TS_UTC ]] || add_failure "WAIVED sem waiver_approved_at em ISO 8601 UTC"
    # waiver_reason é prosa: confere-se que a line existe com conteúdo, sem lê-la.
    grep -qE '^waiver_reason:[[:space:]]+[^[:space:]"]|^waiver_reason:[[:space:]]+"[^"]+"' "$file_path" \
        || add_failure "WAIVED sem waiver_reason"
}

# --- promoções --------------------------------------------------------------
check_promotions() {
    local repo="$1" dir="$2" file_path target mode resolved
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] || continue
        grep -q '^promote:' "$file_path" 2>/dev/null || continue
        target="$(sed -nE 's/^promote:[[:space:]]+"?([^"]*)"?[[:space:]]*$/\1/p' "$file_path" | head -1)"
        mode="$(sed -nE 's/^promote_mode:[[:space:]]+"?([a-z]*)"?[[:space:]]*$/\1/p' "$file_path" | head -1)"
        [[ -n "$mode" ]] || mode=copy
        if ! in_domain "$mode" copy append manual; then
            add_failure "promote_mode inválido em $(basename "$file_path"): '$mode'"; continue
        fi
        if ! resolved="$(validate_promotion_target "$repo" "$target" "$mode" 2>&1)"; then
            add_failure "promote inválido em $(basename "$file_path"): $resolved"; continue
        fi
        [[ "$mode" == manual ]] && continue
        if [[ ! -f "$resolved" ]]; then
            add_failure "promote não aplicado: $(basename "$file_path") -> $target"; continue
        fi
        if [[ "$mode" == copy ]] && ! cmp -s "$file_path" "$resolved"; then
            add_failure "promote copy divergente: $(basename "$file_path") -> $target"
        fi
    done < <(find "$dir" -type f -name '*.md' -print 2>/dev/null)
}

# --- subcomando: ship-ready -------------------------------------------------
cmd_ship_ready() {
    local repo branch dir prefix
    repo="$(get_repo_root)"; branch="$(get_current_branch)"
    if [[ ! "$branch" =~ ^([a-z][a-z-]*/)?([0-9]{3})- ]]; then
        SPEC_ID=""; PHASE=""
        emit "ship-ready"; return $?
    fi
    prefix="${BASH_REMATCH[2]}"; SPEC_ID="$prefix"
    if ! dir="$(resolve_spec_dir "$repo" "$branch" any 2>&1)"; then
        add_failure "add_failure ao resolver spec do branch '$branch': $dir"
        emit "ship-ready"; return $?
    fi
    [[ -f "$dir/spec-meta.yaml" ]] || { add_failure "spec-meta.yaml ausente em $dir"; emit "ship-ready"; return $?; }

    SPEC_ID="$(read_field "$dir/spec-meta.yaml" spec_id)"
    PHASE="$(read_field "$dir/spec-meta.yaml" current_phase)"
    local status; status="$(read_field "$dir/spec-meta.yaml" status)"

    in_domain "$PHASE" $PHASES || add_failure "current_phase inválido ou ilegível: '$PHASE'"
    in_domain "$status" $VALID_STATUS || add_failure "status inválido ou ilegível: '$status'"
    [[ "$PHASE" == "archived" ]] || add_failure "current_phase='$PHASE' (expected 'archived'; a spec não passed pelo archive)"
    [[ "$status" == "archived" || "$PHASE" != "archived" ]] || add_failure "status e current_phase divergem"

    check_gate_allows_completion "$dir"
    check_promotions "$repo" "$dir"
    if has_git && [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
        add_failure "working tree sujo (mudanças não commitadas)"
    fi
    emit "ship-ready"
}

# --- subcomando: prerequisites ----------------------------------------------
cmd_prerequisites() {
    local repo dir target_phase="$FOR_PHASE"
    repo="$(get_repo_root)"
    [[ -n "$target_phase" ]] || { echo "prerequisites exige --for <phase>" >&2; exit 2; }
    in_domain "$target_phase" $PHASES || { echo "phase desconhecida: $target_phase" >&2; exit 2; }
    if ! dir="$(resolve_spec_dir "$repo" "${SPEC_LOCATOR:-$(get_current_branch)}" any 2>&1)"; then
        add_failure "add_failure ao resolver spec: $dir"; emit "prerequisites"; return $?
    fi
    SPEC_ID="$(read_field "$dir/spec-meta.yaml" spec_id)"
    PHASE="$target_phase"

    local always="spec.md"
    case "$target_phase" in
        tasks|implement|qa-gate|archived) always="spec.md plan.md" ;;
    esac
    case "$target_phase" in
        implement|qa-gate|archived) always="spec.md plan.md tasks.md" ;;
    esac
    local a
    for a in $always; do
        [[ -s "$dir/$a" ]] || { add_failure "$a ausente ou vazio"; continue; }
        grep -qF "$BLOCKING_MARKER" "$dir/$a" 2>/dev/null \
            && add_failure "$a ainda contém esclarecimento bloqueante"
    done
    case "$target_phase" in
        qa-gate|archived)
            grep -qE "$OPEN_TASK_PATTERN" "$dir/tasks.md" 2>/dev/null \
                && add_failure "tasks.md possui tarefas abertas"
            ;;
    esac
    [[ "$target_phase" == "archived" ]] && { check_gate_allows_completion "$dir"; check_promotions "$repo" "$dir"; }
    emit "prerequisites"
}

# --- subcomando: install ----------------------------------------------------
cmd_install() {
    # SCRIPT_DIR = <root>/.claude/mosk/scripts  ->  ../..  = <root>/.claude
    local root="$SCRIPT_DIR/../.." s
    for s in "$SCRIPT_DIR"/*.sh; do
        bash -n "$s" 2>/dev/null || add_failure "erro de sintaxe em $(basename "$s")"
    done
    [[ -f "$PIPELINE_YAML" ]] || add_failure "pipeline.yaml ausente — a regra do pipeline não tem fonte"
    local required
    for required in "$SCRIPT_DIR/../core-config.yaml" "$SCRIPT_DIR/../pipeline.yaml"; do
        [[ -f "$required" ]] || add_failure "file_path obrigatório ausente: $(basename "$required")"
    done
    local agent_count
    agent_count="$(find "$root/agents" -maxdepth 1 -name 'mosk-*.md' 2>/dev/null | wc -l | tr -d ' ')"
    [[ "$agent_count" -ge 1 ]] || add_failure "nenhum agente encontrado em .claude/agents/"
    SPEC_ID=""; PHASE=""
    emit "install"
}

# --- subcomando: self-check -------------------------------------------------
# Confere as constantes espelhadas contra o pipeline.yaml. Precisa de um parser
# YAML; sem ele, AVISA e passa — FR-007 proíbe exigir PyYAML/npm/pip.
cmd_self_check() {
    SPEC_ID=""; PHASE=""
    if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
        echo "self-check: PULADO (sem parser YAML disponível — não é dependência obrigatória)" >&2
        emit "self-check"; return $?
    fi
    local output
    output="$(python3 - "$PIPELINE_YAML" "$PHASES" "$VERDICTS" "$VERDICTS_ALLOWING_COMPLETION" "$CONFIRMED_BY" <<'PY'
import sys, yaml
p, fases, vereditos, conclui, confirma = sys.argv[1:6]
d = yaml.safe_load(open(p))
erros = []
if list(d['phases'].keys()) != fases.split():
    erros.append(f"PHASES divergem: script={fases.split()} yaml={list(d['phases'].keys())}")
if d['gate']['verdicts'] != vereditos.split():
    erros.append(f"VERDICTS divergem: script={vereditos.split()} yaml={d['gate']['verdicts']}")
ok_yaml = sorted(k for k, v in d['gate']['allows_completion'].items() if v is not False)
if ok_yaml != sorted(conclui.split()):
    erros.append(f"VERDICTS_ALLOWING_COMPLETION divergem: script={sorted(conclui.split())} yaml={ok_yaml}")
# CONFIRMED_BY ancora o `tasks-sync` na fonte: sem esta comparação, aquele
# subcomando validaria as tasks contra uma constante que poderia ter derivado
# do pipeline.yaml sem ninguém notar.
pares_yaml = sorted(
    f"{name}:{cmd}"
    for name, ph in d["phases"].items()
    for cmd in (ph.get("confirmed_by") or [])
)
if pares_yaml != sorted(confirma.split()):
    erros.append(f"CONFIRMED_BY diverge: script={sorted(confirma.split())} yaml={pares_yaml}")
print("\n".join(erros))
PY
)" || { add_failure "self-check não pôde rodar"; emit "self-check"; return $?; }
    [[ -z "$output" ]] || while IFS= read -r l; do [[ -n "$l" ]] && add_failure "$l"; done <<< "$output"
    emit "self-check"
}

# --- subcomando: fixtures ---------------------------------------------------
cmd_fixtures() {
    SPEC_ID=""; PHASE=""
    local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/mosk-validate-fx.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    local passed=0 total=0
    assert_case() {
        total=$((total + 1))
        local name="$1" expected="$2"; shift 2
        local got_value; got_value="$("$@" 2>/dev/null || true)"
        if [[ "$got_value" == "$expected" ]]; then passed=$((passed + 1))
        else add_failure "fixture '$name' :: expected '$expected' :: got_value '$got_value'"; fi
    }
    local g="$tmp/gate.yaml"

    printf 'gate: "PASS"\n' > "$g"
    assert_case "gate PASS entre aspas" "PASS" read_field "$g" gate
    printf 'gate: PASS\n' > "$g"
    assert_case "gate PASS sem aspas" "PASS" read_field "$g" gate

    # Fail-closed: as formas que o ADR-0020 levou treze voltas para recusar.
    printf 'gate: {x: PASS}\n' > "$g"
    assert_case "coleção inline recusada" "" read_field "$g" gate
    printf 'gate: |\n  PASS\n' > "$g"
    assert_case "escalar em bloco recusado" "" read_field "$g" gate
    printf 'gate: PASS\ngate: FAIL\n' > "$g"
    assert_case "key duplicada recusada" "" read_field "$g" gate
    printf '  gate: PASS\n' > "$g"
    assert_case "key indentada recusada" "" read_field "$g" gate
    printf 'gate: PASS # comentário\n' > "$g"
    assert_case "comentário na line recusado" "" read_field "$g" gate
    printf 'not_gate: PASS\n' > "$g"
    assert_case "key diferente não casa" "" read_field "$g" gate

    # Domínio fechado: o que não é verdict não passa, seja qual for a forma.
    in_domain "PASS" $VERDICTS && assert_case "PASS em domínio" "" true
    if in_domain "{x}" $VERDICTS; then add_failure "fixture 'value fabricado fora do domínio' :: aceitou '{x}'"; fi
    total=$((total + 1)); passed=$((passed + 1))

    # T018 — regressão da spec 014: mesclada em qa-gate, sem archive.
    local sd="$tmp/014-feature-x"; mkdir -p "$sd"
    printf 'spec_id: "014-feature-x"\nstatus: active\ncurrent_phase: qa-gate\n' > "$sd/spec-meta.yaml"
    local phase; phase="$(read_field "$sd/spec-meta.yaml" current_phase)"
    total=$((total + 1))
    if [[ "$phase" == "qa-gate" ]]; then passed=$((passed + 1))
    else add_failure "fixture '014: phase lida' :: expected 'qa-gate' :: got_value '$phase'"; fi
    total=$((total + 1))
    if [[ "$phase" != "archived" ]]; then passed=$((passed + 1))
    else add_failure "fixture '014: qa-gate deve reprovar ship-ready' :: passed indevidamente"; fi

    # Guardrail: o hook precisa distinguir INVOCAÇÃO de MENÇÃO. Os dois casos
    # abaixo são falsos positivos reais — o hook bloqueou a si mesmo ao editar
    # um heredoc que citava o comando, e depois ao escrever a mensagem de
    # commit que o descrevia.
    # Guardrail. As duas categorias importam por razões opostas:
    #   - MENÇÃO deve ser ignorada, senão o hook bloqueia trabalho legítimo e
    #     acaba desabilitado (dois falsos positivos reais já aconteceram);
    #   - INVOCAÇÃO deve ser verificada, senão o controle não existe. Foi este
    #     lado que a security review encontrou aberto em sete formas (SEC-001),
    #     porque as fixtures só cobriam o primeiro.
    local hook="$SCRIPT_DIR/../../hooks/guard-spec-merge.sh"
    if [[ -f "$hook" ]] && command -v python3 >/dev/null 2>&1; then
        # `g''h` mantém os verbos quebrados no fonte: um file_path que os cite
        # inteiros é, ele mesmo, um comando que os cita.
        local V_GH="g""h" V_PR="p""r" V_MG="me""rge" V_GIT="gi""t" V_TEA="te""a"
        decision() {
            printf '{"tool_input":{"command":%s}}' "$1" \
                | GUARD_DECIDE_ONLY=1 bash "$hook" 2>/dev/null
        }
        hook_case() {
            local name="$1" cmd="$2" expected="$3"
            total=$((total + 1))
            local got; got="$(decision "\"$cmd\"")"
            if [[ "$got" == "$expected" ]]; then passed=$((passed + 1))
            else add_failure "fixture 'hook: $name' :: expected '$expected' :: got_value '$got'"; fi
        }
        # Sem aspas o texto é indistinguível de comando, e o fail-closed manda
        # verificar — por isso a menção precisa estar citada para ser ignorada.
        local Q="'"
        hook_case "menção citada"       "echo ${Q}rode $V_GH $V_PR $V_MG depois${Q}" ignora
        hook_case "menção entre aspas"  "echo \\\"$V_GH $V_PR $V_MG\\\"" ignora
        hook_case "comando comum"       "ls -la"                             ignora
        # SEC-001 — os sete que passavam
        hook_case "invocação direta"    "$V_GH $V_PR $V_MG 21"               verifica
        hook_case "prefixo de env"     "FOO=bar $V_GH $V_PR $V_MG 21"       verifica
        hook_case "caminho absoluto"    "/usr/bin/$V_GH $V_PR $V_MG 21"      verifica
        hook_case "command builtin"     "command $V_GH $V_PR $V_MG 21"       verifica
        hook_case "newline separando"   "echo oi\\n$V_GH $V_PR $V_MG 21"     verifica
        hook_case "<< em string"        "echo a << b ; $V_GH $V_PR $V_MG 21" verifica
        hook_case "git merge"           "$V_GIT $V_MG feature/x"             verifica
        # Gitea. O guardrail conhecia só o GitHub e `tea pr create` passava
        # inteiro — este repositório usa os dois. O CLI aceita `pulls|pull|pr`
        # e `create|c` / `merge|m`, então o reconhecimento é por conjunto e não
        # por tupla enumerada: enumerar foi como a forma escapou.
        hook_case "tea pr create"       "$V_TEA $V_PR create"                verifica
        hook_case "tea pr merge"        "$V_TEA $V_PR $V_MG 12"              verifica
        hook_case "tea pulls create"    "$V_TEA pulls create"                verifica
        hook_case "tea alias c"         "$V_TEA $V_PR c"                     verifica
        hook_case "tea pr list"         "$V_TEA $V_PR list"                  ignora
    fi

    [[ ${#FAILURES[@]} -eq 0 ]] && echo "fixtures: $passed/$total"
    emit "fixtures"
}

# --- subcomando: tasks-sync -------------------------------------------------
# Fecha o laço da tese da spec 016 (achado QA-2). A regra virou dado, e o
# `self-check` confere que as constantes deste script batem com o pipeline.yaml
# — mas nada conferia que as TASKS batem com a regra. Se uma aresta mudasse no
# YAML e as seis tasks de phase mantivessem o fluxo antigo, nenhuma verificação
# acusava.
#
# Encadeando as duas: tasks ≡ constantes ≡ pipeline.yaml.
# Roda em shell puro, sem parser: compara contra as constantes, não contra o
# YAML — é o `self-check` que ancora as constantes na fonte.
cmd_tasks_sync() {
    SPEC_ID=""; PHASE=""
    local tasks_dir="$SCRIPT_DIR/../tasks" arq base line phase cmd par achou d
    local declared=""
    for arq in "$tasks_dir"/*.md; do
        base="$(basename "$arq")"
        # Formas declaradas nas tasks, em inglês e em português.
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            phase="$(printf '%s' "$line" | sed -nE 's/.*(transition to|transição para) `([a-z-]+)`.*/\2/p')"
            cmd="$(printf '%s' "$line" | sed -nE 's/.*(with command|com o comando) `([a-z-]+)`.*/\2/p')"
            [[ -n "$phase" && -n "$cmd" ]] || continue
            declared="$declared $phase:$cmd"
            in_domain "$phase" $PHASES \
                || { add_failure "$base :: phase inexistente no pipeline: '$phase'"; continue; }
            achou=0
            for par in $CONFIRMED_BY; do [[ "$par" == "$phase:$cmd" ]] && achou=1; done
            [[ $achou -eq 1 ]] \
                || add_failure "$base :: comando '$cmd' não confirma a phase '$phase' (ver confirmed_by em pipeline.yaml)"
        done < <(grep -hoE '(transition to|transição para) `[a-z-]+` (with command|com o comando) `[a-z-]+`' "$arq" 2>/dev/null)
    done
    # O outro lado: toda dupla declarada na regra tem alguma task que a exerce?
    # Uma aresta sem task é aresta morta — ou a regra sobra, ou a task sumiu.
    for par in $CONFIRMED_BY; do
        case " $declared " in
            *" $par "*) ;;
            *) add_failure "nenhuma task declara a transição '$par' — aresta sem quem a exerça" ;;
        esac
    done
    emit "tasks-sync"
}

# --- subcomando: single-source ----------------------------------------------
# Contratos em data/ declaram uma redação normativa entre marcadores
# `contract-normative`. Copiá-la para outro file_path cria uma segunda fonte que
# diverge em silêncio. Herdado de `audit-legacy-surface.sh`.
cmd_single_source() {
    SPEC_ID=""; PHASE=""
    local data_dir="$SCRIPT_DIR/../data" contract base line n outro
    for contract in "$data_dir"/*-contract.md; do
        [[ -f "$contract" ]] || continue
        base="$(basename "$contract")"
        # Linhas normativas: >= 30 caracteres, dentro dos marcadores.
        while IFS= read -r line; do
            [[ ${#line} -ge 30 ]] || continue
            n=0
            while IFS= read -r outro; do
                [[ "$(basename "$outro")" == "$base" ]] && continue
                n=$((n + 1))
            done < <(grep -rlF "$line" "$SCRIPT_DIR/.." --include='*.md' 2>/dev/null || true)
            [[ $n -eq 0 ]] || echo "$base|$line"
        done < <(sed -n '/contract-normative:start/,/contract-normative:end/p' "$contract" \
                 | grep -vE '^[[:space:]]*[|#>`-]' | grep -vE '^[[:space:]]*$') \
        | sort | uniq -c | awk -F'|' -v b="$base" '{ n++ } END { if (n >= 3) print b " :: " n " linhas normativas reaparecem literalmente em outro file_path" }' \
        | while IFS= read -r v; do [[ -n "$v" ]] && add_failure "$v"; done
    done
    emit "single-source"
}

# --- subcomando: docs-paths -------------------------------------------------
# Só caminhos DECLARADOS como saída contam. Uma task pode citar `docs/prd.md`
# ao descrever a estrutura legada que ela migra — isso não é uma saída, e
# tratá-lo como tal produz falso positivo (foi o que a primeira versão fez).
cmd_docs_paths() {
    SPEC_ID=""; PHASE=""
    local domains="discovery prd architecture ui qa specs handoff project"
    local intro_pattern='(\*\*Save to:\*\*|Save to:|Save it as|save it as|Create the document as|Write to:|Output to:|Save the populated document to)'
    local source target dom ok d line
    check_target() {
        local arq="$1" target="$2"
        [[ -n "$target" ]] || return 0
        dom="${target#docs/}"; dom="${dom%%/*}"
        ok=0
        for d in $domains; do [[ "$dom" == "$d" ]] && ok=1; done
        [[ "$dom" == "index.md" ]] && ok=1
        [[ $ok -eq 1 ]] || add_failure "$arq :: saída fora dos domínios canônicos -> $target"
    }
    # R1: prosa de task que intro_pattern um caminho de saída
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        source="$(basename "${line%%:*}")"
        target="$(printf '%s' "$line" | grep -oE 'docs/[A-Za-z0-9./_-]+\.md' | head -1)"
        check_target "$source" "$target"
    done < <(grep -rnEi "$intro_pattern[[:space:]]*\`?docs/" "$SCRIPT_DIR/../tasks" 2>/dev/null || true)
    # R2/R3: campos estruturais que declaram target_phase
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        source="$(basename "${line%%:*}")"
        target="$(printf '%s' "$line" | sed -E 's/^.*(filename|docOutputLocation):[[:space:]]*//' | tr -d "'\"" | awk '{print $1}')"
        check_target "$source" "$target"
    done < <(grep -rnE '^[[:space:]]*(filename|docOutputLocation):[[:space:]]*docs/' \
                  "$SCRIPT_DIR/../tasks" "$SCRIPT_DIR/../templates" 2>/dev/null || true)
    # R4: referência `<domínio>.<key>` de config existe no core-config.yaml
    local cfg="$SCRIPT_DIR/../core-config.yaml" ref dominio key
    if [[ -f "$cfg" ]]; then
        while IFS= read -r ref; do
            [[ -n "$ref" ]] || continue
            dominio="${ref%%.*}"; key="${ref#*.}"
            awk -v d="$dominio" -v k="$key" '
                $0 ~ "^" d ":" { dentro=1; next }
                /^[a-zA-Z]/ { dentro=0 }
                dentro && $0 ~ "^[[:space:]]+" k "[[:space:]]*:" { achou=1 }
                END { exit !achou }
            ' "$cfg" || add_failure "referência de config inexistente em core-config.yaml: $ref"
        done < <(grep -rhoE '`(qa|prd|architecture|ui|discovery|specs|runner)\.[a-zA-Z]+`' \
                 "$SCRIPT_DIR/../tasks" 2>/dev/null | tr -d '`' \
                 | grep -vE '\.(md|yaml|yml|sh|json|txt)$' | sort -u)
    fi

    # R5: todo template citado por uma task existe no disco
    local tpl
    while IFS= read -r tpl; do
        [[ -n "$tpl" ]] || continue
        [[ -f "$SCRIPT_DIR/../templates/$tpl" ]] \
            || add_failure "template citado por task não existe: templates/$tpl"
    done < <(grep -rhoE 'templates/[a-z0-9-]+-tmpl\.(md|yaml)|templates/[a-z0-9-]+-template\.md' \
             "$SCRIPT_DIR/../tasks" 2>/dev/null | sed 's|templates/||' | sort -u)

    emit "docs-paths"
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
    single-source) cmd_single_source ;;
    tasks-sync)    cmd_tasks_sync ;;
    self-check)    cmd_self_check ;;
    fixtures)      cmd_fixtures ;;
    all)
        rc=0
        for s in install self-check docs-paths single-source tasks-sync fixtures ship-ready; do
            FAILURES=(); SPEC_ID=""; PHASE=""
            "cmd_${s//-/_}" || rc=1
        done
        exit $rc
        ;;
    --help|-h) usage; exit 0 ;;
    *) echo "subcomando desconhecido: $SUB" >&2; usage >&2; exit 2 ;;
esac
