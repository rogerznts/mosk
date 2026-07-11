#!/usr/bin/env bash

set -e

JSON_MODE=false
SHORT_NAME=""
BRANCH_NUMBER=""
FEATURE_TYPE=""
EXTENDS=""
NO_PUSH=false
MAX_RETRIES=3
MAX_RESERVE_ATTEMPTS=5
ARGS=()
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --short-name)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            # Check if the next argument is another option (starts with --)
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            SHORT_NAME="$next_arg"
            ;;
        --type)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --type requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --type requires a value' >&2
                exit 1
            fi
            FEATURE_TYPE="$next_arg"
            ;;
        --extends)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --extends requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --extends requires a value' >&2
                exit 1
            fi
            EXTENDS="$next_arg"
            ;;
        --number)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --number requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --number requires a value' >&2
                exit 1
            fi
            BRANCH_NUMBER="$next_arg"
            ;;
        --no-push)
            NO_PUSH=true
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--type <type>] [--extends <spec-id>] [--short-name <name>] [--number N] [--no-push] <feature_description>"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --type <type>       Spec type: feature|fix|hotfix|gmud|refactor|experimental|extension"
            echo "  --extends <spec-id> Parent spec this one extends (REQUIRED when --type=extension)"
            echo "  --short-name <name> Provide a custom short name (2-4 words) for the branch"
            echo "  --number N          Specify branch number manually (overrides auto-detection)"
            echo "  --no-push           Do not push the new branch to origin (useful for forks or offline work)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Concurrency: before creating the branch, the script atomically"
            echo "reserves the spec number on 'origin' via an immutable ref"
            echo "(refs/spec-numbers/<NNN>). If another creator grabbed the same"
            echo "number first, git rejects the reservation and the script renumbers"
            echo "and retries. These refs are invisible to 'git branch'/'git tag' and"
            echo "form a durable registry, so a number is never reused even after its"
            echo "branch is merged and deleted. Remotes that reject custom refs fall"
            echo "back to best-effort branch/dir detection."
            echo ""
            echo "Examples:"
            echo "  $0 --type feature --short-name 'user-auth' 'Add user authentication system'"
            echo "  $0 --type fix --short-name 'payment-timeout' 'Fix payment processing timeout'"
            echo "  $0 --type gmud --number 5 'Deploy rollback procedure'"
            echo "  $0 --type extension --extends 005-feature-checkout-coupon 'Add coupon usage cap per user'"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
    i=$((i + 1))
done

FEATURE_DESCRIPTION="${ARGS[*]}"
if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Usage: $0 [--json] [--short-name <name>] [--number N] <feature_description>" >&2
    exit 1
fi

# Remember an explicitly requested number so retries never silently
# renumber it; auto-assignment leaves this empty.
MANUAL_NUMBER="$BRANCH_NUMBER"

# When the spec type is `extension`, the parent spec id is mandatory.
# Extensions are used to extend an already-archived spec without
# breaking archive immutability (see Document Organization in the
# project rules).
if [ "$FEATURE_TYPE" = "extension" ] && [ -z "$EXTENDS" ]; then
    echo "Error: --type extension requires --extends <spec-id>" >&2
    echo "Example: $0 --type extension --extends 005-feature-checkout-coupon 'Add coupon cap'" >&2
    exit 1
fi

# --extends only makes sense with --type extension. Warn but do not
# fail, so callers experimenting with linkage between sibling specs
# are not blocked.
if [ -n "$EXTENDS" ] && [ "$FEATURE_TYPE" != "extension" ]; then
    >&2 echo "[specify] Warning: --extends '$EXTENDS' is set but --type is not 'extension'; the link will still be written to spec-meta.yaml."
fi

# Function to find the repository root by searching for existing project markers
find_repo_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -d "$dir/.claude/mosk" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Function to find the highest feature number across ALL branches and spec dirs
# This prevents number collisions when creating branches with different suffixes
get_next_global_number() {
    local max_num=0

    # Fetch all remotes to get latest branch info (suppress errors if no remotes)
    git fetch --all --prune 2>/dev/null || true

    # Check ALL remote feature branches (any name, just extract the numeric prefix)
    local remote_nums=$(git ls-remote --heads origin 2>/dev/null | grep -oE 'refs/heads/[0-9]+' | grep -oE '[0-9]+' | sort -n)

    # Check durable number reservations (refs/spec-numbers/*). These are
    # immutable and survive branch deletion, so an archived/merged spec's
    # number is never handed out twice.
    local reserved_nums=$(git ls-remote origin 'refs/spec-numbers/*' 2>/dev/null | grep -oE 'refs/spec-numbers/[0-9]+' | grep -oE '[0-9]+$' | sort -n)

    # Check ALL local feature branches
    local local_nums=$(git branch 2>/dev/null | grep -oE '[0-9]{3}-' | grep -oE '[0-9]+' | sort -n)

    # Check ALL spec directories (active + archived) so numbers are not reused
    local spec_nums="" archived_nums=""
    if [ -d "$SPECS_DIR" ]; then
        spec_nums=$(find "$SPECS_DIR" -maxdepth 1 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -oE '^[0-9]+' | sort -n)
    fi
    if [ -d "$SPECS_DIR/archive" ]; then
        archived_nums=$(find "$SPECS_DIR/archive" -maxdepth 1 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -oE '^[0-9]+' | sort -n)
    fi

    # Combine all sources and get the highest number
    for num in $remote_nums $reserved_nums $local_nums $spec_nums $archived_nums; do
        num=$((10#$num))  # force base-10 to avoid octal issues
        if [ "$num" -gt "$max_num" ]; then
            max_num=$num
        fi
    done

    # Return next number
    echo $((max_num + 1))
}

# Resolve repository root. Prefer git information when available, but fall back
# to searching for repository markers so the workflow still functions in repositories that
# were initialised with --no-git.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    HAS_GIT=true
else
    REPO_ROOT="$(find_repo_root "$SCRIPT_DIR")"
    if [ -z "$REPO_ROOT" ]; then
        echo "Error: Could not determine repository root. Please run this script from within the repository." >&2
        exit 1
    fi
    HAS_GIT=false
fi

cd "$REPO_ROOT"

# Whether we can talk to an 'origin' remote (needed for atomic number
# reservation and remote collision checks).
ORIGIN_AVAILABLE=false
if [ "$HAS_GIT" = true ] && git remote get-url origin >/dev/null 2>&1; then
    ORIGIN_AVAILABLE=true
fi

# Guard: only allow branch creation from stable base branches
# Blocked branches: environment, release, and any existing feature branch
ALLOWED_BASE_BRANCHES="main master develop dev"
BLOCKED_BRANCH_PATTERNS="^(release|hotfix|hml|homolog|homologacao|staging|stage|stg|preprod|pre-prod|prod|production|qa|uat|sit|feat|feature|bugfix|fix|support|sandbox|demo|test|testing|ci|cd|infra|ops|deploy|v[0-9])/|^(hml|homolog|homologacao|staging|stage|stg|preprod|pre-prod|prod|production|qa|uat|sit|sandbox|demo|test|testing|release|ci|cd|infra|ops|deploy)$"

if [ "$HAS_GIT" = true ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ]; then
        is_allowed=false
        for allowed in $ALLOWED_BASE_BRANCHES; do
            if [ "$CURRENT_BRANCH" = "$allowed" ]; then
                is_allowed=true
                break
            fi
        done

        # Also block branches matching environment/release patterns
        if echo "$CURRENT_BRANCH" | grep -qE "$BLOCKED_BRANCH_PATTERNS"; then
            is_allowed=false
        fi

        # Block if on an existing feature branch (numeric prefix like 001-*)
        if echo "$CURRENT_BRANCH" | grep -qE '^[0-9]{3}-'; then
            is_allowed=false
        fi

        if [ "$is_allowed" = false ]; then
            echo "ERROR: Cannot create a new feature branch from '$CURRENT_BRANCH'." >&2
            echo "New branches can only be created from: $ALLOWED_BASE_BRANCHES" >&2
            echo "Switch to a base branch first, e.g.: git checkout main" >&2
            exit 1
        fi
    fi
fi

SPECS_DIR="$REPO_ROOT/docs/specs"
mkdir -p "$SPECS_DIR"

# Function to generate branch name with stop word filtering and length filtering
generate_branch_name() {
    local description="$1"
    
    # Common stop words to filter out
    local stop_words="^(i|a|an|the|to|for|of|in|on|at|by|with|from|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|can|may|might|must|shall|this|that|these|those|my|your|our|their|want|need|add|get|set)$"
    
    # Convert to lowercase and split into words
    local clean_name=$(echo "$description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g')
    
    # Filter words: remove stop words and words shorter than 3 chars (unless they're uppercase acronyms in original)
    local meaningful_words=()
    for word in $clean_name; do
        # Skip empty words
        [ -z "$word" ] && continue
        
        # Keep words that are NOT stop words AND (length >= 3 OR are potential acronyms)
        if ! echo "$word" | grep -qiE "$stop_words"; then
            if [ ${#word} -ge 3 ]; then
                meaningful_words+=("$word")
            elif echo "$description" | grep -q "\b${word^^}\b"; then
                # Keep short words if they appear as uppercase in original (likely acronyms)
                meaningful_words+=("$word")
            fi
        fi
    done
    
    # If we have meaningful words, use first 3-4 of them
    if [ ${#meaningful_words[@]} -gt 0 ]; then
        local max_words=3
        if [ ${#meaningful_words[@]} -eq 4 ]; then max_words=4; fi
        
        local result=""
        local count=0
        for word in "${meaningful_words[@]}"; do
            if [ $count -ge $max_words ]; then break; fi
            if [ -n "$result" ]; then result="$result-"; fi
            result="$result$word"
            count=$((count + 1))
        done
        echo "$result"
    else
        # Fallback to original logic if no meaningful words found
        echo "$description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//' | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//'
    fi
}

# Generate branch name
if [ -n "$SHORT_NAME" ]; then
    # Use provided short name, just clean it up
    BRANCH_SUFFIX=$(echo "$SHORT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//')
else
    # Generate from description with smart filtering
    BRANCH_SUFFIX=$(generate_branch_name "$FEATURE_DESCRIPTION")
fi

# GitHub enforces a 244-byte limit on branch names.
MAX_BRANCH_LENGTH=244

# List spec numbers already reserved on origin (see refs/spec-numbers/*
# below). Echoes one integer per line; empty when there is no origin.
list_reserved_numbers() {
    [ "$HAS_GIT" = true ] && [ "$ORIGIN_AVAILABLE" = true ] || return 0
    git ls-remote origin 'refs/spec-numbers/*' 2>/dev/null \
        | grep -oE 'refs/spec-numbers/[0-9]+' | grep -oE '[0-9]+$'
}

# True when we can atomically reserve numbers on origin.
reservation_available() {
    [ "$HAS_GIT" = true ] && [ "$ORIGIN_AVAILABLE" = true ] && [ "$NO_PUSH" = false ]
}

# Atomically reserve a spec number on origin by creating the immutable
# ref refs/spec-numbers/<NNN>. It pushes a UNIQUE dangling commit under a
# "must-not-exist" lease (--force-with-lease=<ref>: with empty expected
# value). The uniqueness is essential: if two creators pushed the same
# object git would short-circuit with "Everything up-to-date" and never
# evaluate the lease. With distinct objects, exactly one push wins and the
# loser is rejected with "stale info". Returns 0 when we won the number,
# non-zero when it was already taken (or the push failed). Verified against
# GitHub; degrades gracefully on remotes that reject custom ref namespaces.
reserve_spec_number() {
    local n="$1" tree commit gu gm nonce
    tree=$(git hash-object -t tree /dev/null 2>/dev/null) || return 1
    gu=$(git config user.name 2>/dev/null); [ -n "$gu" ] || gu="mosk"
    gm=$(git config user.email 2>/dev/null); [ -n "$gm" ] || gm="mosk@local"
    nonce="${n}-$(date -u +%s)-$$-${RANDOM}${RANDOM}-$(hostname 2>/dev/null || echo host)"
    commit=$(GIT_AUTHOR_NAME="$gu" GIT_AUTHOR_EMAIL="$gm" \
             GIT_COMMITTER_NAME="$gu" GIT_COMMITTER_EMAIL="$gm" \
             git commit-tree "$tree" -m "mosk: reserve spec number $nonce" 2>/dev/null) || return 1
    git push --force-with-lease="refs/spec-numbers/$n:" origin \
        "${commit}:refs/spec-numbers/$n" >/dev/null 2>&1
}

# Build BRANCH_NAME / FEATURE_NUM from the current BRANCH_NUMBER and
# enforce GitHub's branch-name byte limit.
rebuild_branch_name() {
    FEATURE_NUM=$(printf "%03d" "$BRANCH_NUMBER")
    local prefix
    if [ -n "$FEATURE_TYPE" ]; then
        CLEAN_TYPE=$(echo "$FEATURE_TYPE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
        prefix="${FEATURE_NUM}-${CLEAN_TYPE}-"
    else
        prefix="${FEATURE_NUM}-"
    fi
    BRANCH_NAME="${prefix}${BRANCH_SUFFIX}"
    if [ ${#BRANCH_NAME} -gt $MAX_BRANCH_LENGTH ]; then
        local max_suffix=$((MAX_BRANCH_LENGTH - ${#prefix}))
        local trimmed
        trimmed=$(echo "$BRANCH_SUFFIX" | cut -c1-"$max_suffix" | sed 's/-$//')
        local original="$BRANCH_NAME"
        BRANCH_NAME="${prefix}${trimmed}"
        >&2 echo "[specify] Warning: Branch name exceeded GitHub's ${MAX_BRANCH_LENGTH}-byte limit"
        >&2 echo "[specify] Original: $original (${#original} bytes)"
        >&2 echo "[specify] Truncated to: $BRANCH_NAME (${#BRANCH_NAME} bytes)"
    fi
}

# Pick a spec number and, when a live origin allows it, reserve it
# atomically so two concurrent creators can never grab the same number.
# Sets BRANCH_NUMBER, FEATURE_NUM, BRANCH_NAME and (on success) marks
# NUMBER_RESERVED=true.
NUMBER_RESERVED=false
acquire_spec_number() {
    # Explicit --number: honor it strictly. Never silently renumber; fail
    # loudly when it is already taken so the caller picks another.
    if [ -n "$MANUAL_NUMBER" ]; then
        BRANCH_NUMBER="$MANUAL_NUMBER"
        rebuild_branch_name
        if reservation_available; then
            git fetch --all --prune >/dev/null 2>&1 || true
            if reserve_spec_number "$FEATURE_NUM"; then
                NUMBER_RESERVED=true
            else
                echo "Error: spec number $FEATURE_NUM is already reserved or in use on origin." >&2
                echo "       Choose another with --number, or omit --number to auto-assign." >&2
                exit 1
            fi
        elif [ -d "$SPECS_DIR" ] && ls -d "$SPECS_DIR/${FEATURE_NUM}-"*/ >/dev/null 2>&1; then
            echo "Error: a spec directory with number $FEATURE_NUM already exists locally." >&2
            echo "       Choose another with --number, or omit --number to auto-assign." >&2
            exit 1
        fi
        return
    fi

    if reservation_available; then
        local attempt=1
        while [ "$attempt" -le "$MAX_RESERVE_ATTEMPTS" ]; do
            BRANCH_NUMBER=$(get_next_global_number)   # fetches + unions reservations
            rebuild_branch_name
            if reserve_spec_number "$FEATURE_NUM"; then
                NUMBER_RESERVED=true
                return
            fi
            >&2 echo "[specify] Number $FEATURE_NUM was just reserved by another creator; retrying ($attempt/$MAX_RESERVE_ATTEMPTS)…"
            attempt=$((attempt + 1))
        done
        >&2 echo "[specify] Warning: could not atomically reserve a number after $MAX_RESERVE_ATTEMPTS attempts."
        >&2 echo "[specify]          Proceeding best-effort; the branch-name push still guards exact-name collisions."
        BRANCH_NUMBER=$(get_next_global_number)
        rebuild_branch_name
        return
    fi

    # No origin / --no-push / no git: best-effort local numbering.
    if [ "$HAS_GIT" = true ]; then
        BRANCH_NUMBER=$(get_next_global_number)
    else
        local highest=0 d dn num
        for d in "$SPECS_DIR"/* "$SPECS_DIR"/archive/*; do
            [ -d "$d" ] || continue
            dn=$(basename "$d")
            num=$(echo "$dn" | grep -oE '^[0-9]+' || echo "0")
            num=$((10#$num))
            [ "$num" -gt "$highest" ] && highest=$num
        done
        BRANCH_NUMBER=$((highest + 1))
    fi
    rebuild_branch_name
    >&2 echo "[specify] Note: atomic number reservation unavailable (no origin or --no-push); using best-effort local numbering."
}

acquire_spec_number

# Write initial spec-meta.yaml for the new spec.
write_initial_spec_meta() {
    local spec_dir="$1"
    local spec_number="$2"
    local spec_id="$3"
    local spec_type="$4"
    local spec_branch="$5"
    local spec_extends="$6"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local created_by=""
    if [ "$HAS_GIT" = true ]; then
        local gu gm
        gu=$(git config user.name 2>/dev/null || echo "")
        gm=$(git config user.email 2>/dev/null || echo "")
        if [ -n "$gu" ] && [ -n "$gm" ]; then
            created_by="$gu <$gm>"
        elif [ -n "$gu" ]; then
            created_by="$gu"
        fi
    fi
    cat > "$spec_dir/spec-meta.yaml" <<EOF
spec_number: "$spec_number"
spec_id: "$spec_id"
type: "${spec_type:-feature}"
branch: "$spec_branch"
created_at: "$now"
created_by: "$created_by"
status: active
current_phase: specify
last_phase_change: "$now"
EOF
    if [ -n "$spec_extends" ]; then
        echo "extends: \"$spec_extends\"" >> "$spec_dir/spec-meta.yaml"
    fi
}

# Set up branch + folder. In git mode, also push atomically with retry
# on collision. Prints the final BRANCH_NAME that won the race.
create_branch_and_folder() {
    local attempt=1
    while true; do
        if [ "$HAS_GIT" = true ]; then
            git checkout -b "$BRANCH_NAME" >/dev/null 2>&1 || {
                # Local branch with that name already exists — pick next number.
                >&2 echo "[specify] Local branch $BRANCH_NAME already exists, renumbering…"
                renumber_and_rebuild
                attempt=$((attempt + 1))
                [ $attempt -le $MAX_RETRIES ] && continue
                echo "Error: Could not create branch after $MAX_RETRIES attempts." >&2
                exit 1
            }
        else
            >&2 echo "[specify] Warning: Git repository not detected; skipped branch creation for $BRANCH_NAME"
        fi

        FEATURE_DIR="$SPECS_DIR/$BRANCH_NAME"
        mkdir -p "$FEATURE_DIR"

        TEMPLATE="$REPO_ROOT/.claude/mosk/templates/spec-template.md"
        SPEC_FILE="$FEATURE_DIR/spec.md"
        if [ -f "$TEMPLATE" ]; then cp "$TEMPLATE" "$SPEC_FILE"; else touch "$SPEC_FILE"; fi

        write_initial_spec_meta "$FEATURE_DIR" "$FEATURE_NUM" "$BRANCH_NAME" "$FEATURE_TYPE" "$BRANCH_NAME" "$EXTENDS"

        # Try atomic push if git is present and user didn't opt out.
        if [ "$HAS_GIT" = true ] && [ "$NO_PUSH" = false ]; then
            # Check that origin exists
            if ! git remote get-url origin >/dev/null 2>&1; then
                >&2 echo "[specify] No 'origin' remote configured; skipping push."
                return 0
            fi

            # Stage and commit the bootstrap so the push has something to send.
            git add "$FEATURE_DIR" >/dev/null 2>&1 || true
            if git diff --cached --quiet; then
                # Nothing staged (unlikely, but possible in edge cases) — create empty commit
                git commit --allow-empty -m "spec($FEATURE_NUM): bootstrap $BRANCH_NAME" >/dev/null 2>&1 || true
            else
                git commit -m "spec($FEATURE_NUM): bootstrap $BRANCH_NAME" >/dev/null 2>&1 || true
            fi

            if git push -u origin "$BRANCH_NAME" 2>/dev/null; then
                return 0
            fi

            # Push failed — likely the remote already has this number.
            >&2 echo "[specify] Push rejected for $BRANCH_NAME (race with another spec?). Renumbering…"

            # Tear down local state for this attempt
            local losing_branch="$BRANCH_NAME"
            local losing_dir="$FEATURE_DIR"

            # Switch off the branch, delete it, remove the folder
            git checkout - >/dev/null 2>&1 || git checkout main >/dev/null 2>&1 || true
            git branch -D "$losing_branch" >/dev/null 2>&1 || true
            rm -rf "$losing_dir"

            renumber_and_rebuild
            attempt=$((attempt + 1))
            if [ $attempt -gt $MAX_RETRIES ]; then
                echo "Error: Could not acquire a unique spec number after $MAX_RETRIES attempts." >&2
                echo "       Run 'git fetch --all --prune' and try again manually." >&2
                exit 1
            fi
            continue
        fi

        # No push needed — done.
        return 0
    done
}

# Recompute the next number and rebuild BRANCH_NAME / FEATURE_NUM after a
# collision. Abandon any manual number (the collision forced us off it) and
# acquire — and, when possible, atomically reserve — a fresh number.
renumber_and_rebuild() {
    MANUAL_NUMBER=""
    acquire_spec_number
}

create_branch_and_folder

# Set the SPECIFY_FEATURE environment variable for the current session
export SPECIFY_FEATURE="$BRANCH_NAME"

if $JSON_MODE; then
    printf '{"BRANCH_NAME":"%s","SPEC_FILE":"%s","FEATURE_NUM":"%s"}\n' "$BRANCH_NAME" "$SPEC_FILE" "$FEATURE_NUM"
else
    echo "BRANCH_NAME: $BRANCH_NAME"
    echo "SPEC_FILE: $SPEC_FILE"
    echo "FEATURE_NUM: $FEATURE_NUM"
    echo "SPECIFY_FEATURE environment variable set to: $BRANCH_NAME"
fi
