#!/usr/bin/env bash
# ai-coding-stack installer (orchestrator)
# Coordinates: OS detection, agent detection, tool installation, MCP installation,
# font copying, and custom instruction injection.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$REPO_ROOT/scripts"
STATE_FILE="$HOME/.gentle-ai/state.json"

# shellcheck source=lib/os.sh
source "$SCRIPT_DIR/lib/os.sh"

AGENTS=()
AUTO_YES=false
DRY_RUN=false

log() {
    echo "==> $*"
}

warn() {
    echo "WARNING: $*" >&2
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agents)
                if [[ $# -lt 2 ]]; then
                    log "ERROR: --agents requires a value"
                    exit 1
                fi
                IFS=',' read -r -a AGENTS <<< "$2"
                shift 2
                ;;
            --agents=*)
                IFS=',' read -r -a AGENTS <<< "${1#*=}"
                shift
                ;;
            --yes)
                AUTO_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log "ERROR: Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<EOF
Usage: install.sh [OPTIONS]

Options:
  --agents LIST    Comma-separated agent list (kimi,opencode,pi). Overrides auto-detection.
  --yes            Suppress non-critical prompts (detection confirmation, etc.).
                   Critical prompts (overwrite, destructive actions) are always shown.
  --dry-run        Print what would be done without making changes.
  --help, -h       Show this help message.
EOF
}

check_dependencies() {
    if ! command -v python3 &>/dev/null; then
        log "ERROR: python3 is not installed. Install it and try again."
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        log "ERROR: curl is not installed. Install it and try again."
        exit 1
    fi
}

detect_or_resolve_agents() {
    # If --agents provided, use it directly
    if [[ ${#AGENTS[@]} -gt 0 ]]; then
        log "Using agents from --agents flag: ${AGENTS[*]}"
        return
    fi

    # Try state.json
    if [[ -f "$STATE_FILE" ]]; then
        local state_agents
        state_agents="$(python3 - "$STATE_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        state = json.load(f)
    agents = state.get("installed_agents", [])
    if agents:
        print(",".join(str(a) for a in agents))
except Exception:
    pass
PY
)"
        if [[ -n "$state_agents" ]]; then
            IFS=',' read -r -a AGENTS <<< "$state_agents"
            log "Using agents from state.json: ${AGENTS[*]}"
            return
        fi
    fi

    # Auto-detect
    if [[ -f "$SCRIPT_DIR/detect-agents.sh" ]]; then
        local detected
        detected="$("$SCRIPT_DIR/detect-agents.sh" 2>/dev/null || echo "")"
        if [[ -n "$detected" ]]; then
            IFS=',' read -r -a AGENTS <<< "$detected"
            log "Auto-detected agents: ${AGENTS[*]}"

            if [[ "$AUTO_YES" != "true" ]]; then
                echo ""
                read -r -p "Proceed with these agents? [Y/n] " confirm
                case "${confirm,,}" in
                    n|no)
                        log "Aborted by user."
                        exit 0
                        ;;
                esac
            fi
            return
        fi
    fi

    # Fallback: interactive gentle-ai install
    log "No agents configured. Running gentle-ai install interactively..."
    gentle-ai install
    if [[ -f "$STATE_FILE" ]]; then
        local state_agents
        state_agents="$(python3 - "$STATE_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        state = json.load(f)
    agents = state.get("installed_agents", [])
    if agents:
        print(",".join(str(a) for a in agents))
except Exception:
    pass
PY
)"
        if [[ -n "$state_agents" ]]; then
            IFS=',' read -r -a AGENTS <<< "$state_agents"
        fi
    fi
}

configure_gentle_ai_state() {
    if [[ ${#AGENTS[@]} -eq 0 ]]; then
        return 0
    fi

    log "Configuring gentle-ai for agents: ${AGENTS[*]}"

    mkdir -p "$(dirname "$STATE_FILE")"

    local backup="$STATE_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ -f "$STATE_FILE" ]]; then
        cp "$STATE_FILE" "$backup"
        log "Backup of state.json saved to $backup"
    fi

    python3 - "$STATE_FILE" "${AGENTS[@]}" <<'PY'
import json
import os
import sys

state_file = sys.argv[1]
agents = sys.argv[2:]

state = {}
if os.path.isfile(state_file):
    with open(state_file, "r") as f:
        state = json.load(f)

state["installed_agents"] = agents
state["selection_configured"] = True
state["preset"] = state.get("preset", "full-gentleman")
state["persona"] = state.get("persona", "neutral")
state["strict_tdd"] = state.get("strict_tdd", True)

with open(state_file, "w") as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"state.json updated with agents: {', '.join(agents)}")
PY
}

run_sub_script() {
    local script="$1"
    local description="$2"
    local critical="${3:-true}"

    if [[ ! -f "$script" ]]; then
        warn "Script not found: ${script}"
        return 0
    fi

    log "${description}..."

    export DRY_RUN
    export AGENTS
    export AUTO_YES

    if [[ "$critical" == "true" ]]; then
        bash "$script"
    else
        # Non-critical: warn on failure, continue
        bash "$script" || warn "${description} failed (non-critical, continuing)"
    fi
}

main() {
    log "ai-coding-stack installer"
    log "Repo root: $REPO_ROOT"

    parse_args "$@"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN MODE — no changes will be made"
    fi

    # Phase 0: OS check
    os_require_supported
    check_dependencies

    # Phase 1: Agent detection / resolution
    detect_or_resolve_agents

    # Phase 2: Configure gentle-ai state
    configure_gentle_ai_state

    # Phase 3: Sync gentle-ai assets
    if command -v gentle-ai &>/dev/null; then
        log "Syncing gentle-ai assets..."
        gentle-ai sync || warn "gentle-ai sync failed (non-critical)"
    fi

    # Phase 4: Install workspace tools (gentle-ai, engram)
    run_sub_script "$SCRIPT_DIR/install-tools.sh" "Installing workspace tools" true

    # Phase 5: Install MCPs from manifest
    run_sub_script "$SCRIPT_DIR/install-mcps.sh" "Installing MCPs" false

    # Phase 6: Copy fonts to assets
    run_sub_script "$SCRIPT_DIR/install-fonts.sh" "Copying fonts to assets" false

    # Phase 7: Apply custom instructions
    run_sub_script "$SCRIPT_DIR/apply-custom-instructions.sh" "Applying custom instructions" false

    log "Installation complete. Agents configured: ${AGENTS[*]:-(none)}"
}

main "$@"
