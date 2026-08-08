#!/usr/bin/env bash
# Inject custom instruction .md files into agent-specific targets.
# Supports multiple .md files in config/shared/ with HTML-comment frontmatter targeting.
# Files without frontmatter default to agents: [all].
# Idempotent: existing injection blocks are replaced, not duplicated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_DIR="$REPO_ROOT/config/shared"
STATE_FILE="$HOME/.gentle-ai/state.json"

DRY_RUN="${DRY_RUN:-false}"

# Agent targets
KIMI_TARGET="${HOME}/.kimi/KIMI.md"
OPENCODE_CONFIG="${HOME}/.config/opencode/opencode.json"
PI_TARGET="${HOME}/.pi/agent/APPEND_SYSTEM.md"

log() {
    echo "==> $*"
}

warn() {
    echo "WARNING: $*" >&2
}

# Parse agents list from arguments, state.json, or auto-detect
get_agents() {
    if [[ ${#AGENTS[@]} -gt 0 ]]; then
        echo "${AGENTS[@]}"
        return
    fi

    if [[ -f "$STATE_FILE" ]]; then
        local state_agents
        state_agents="$(python3 - "$STATE_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        state = json.load(f)
    agents = state.get("installed_agents", [])
    if agents:
        print(" ".join(str(a) for a in agents))
except Exception:
    pass
PY
)"
        if [[ -n "$state_agents" ]]; then
            echo "$state_agents"
            return
        fi
    fi

    # Auto-detect
    if [[ -f "$SCRIPT_DIR/detect-agents.sh" ]]; then
        local detected
        detected="$("$SCRIPT_DIR/detect-agents.sh" 2>/dev/null || echo "")"
        if [[ -n "$detected" ]]; then
            echo "${detected//,/ }"
            return
        fi
    fi

    echo ""
}

# Extract agents from HTML-comment frontmatter in a .md file
# Format: <!-- ai-coding-stack:meta agents: [kimi, opencode] -->
parse_frontmatter_agents() {
    local file="$1"
    local meta_block
    meta_block="$(sed -n '/<!-- ai-coding-stack:meta/,/-->/p' "$file" 2>/dev/null || true)"

    if [[ -z "$meta_block" ]]; then
        # No frontmatter: default to "all"
        echo "all"
        return
    fi

    local agents_str
    agents_str="$(echo "$meta_block" | grep -oP 'agents:\s*\[.*?\]' | head -1 || true)"

    if [[ -z "$agents_str" ]]; then
        echo "all"
        return
    fi

    # Extract agent names from brackets
    echo "$agents_str" | sed -n 's/.*agents:\s*\[\(.*\)\].*/\1/p' | tr ',' ' ' | sed 's/^ *//;s/ *$//'
}

apply_custom_instructions() {
    if [[ ! -d "$SHARED_DIR" ]]; then
        log "ERROR: Shared config directory not found: ${SHARED_DIR}" >&2
        exit 1
    fi

    local agents_str
    agents_str="$(get_agents)"
    if [[ -z "$agents_str" ]]; then
        log "No agents configured or detected. Skipping custom instructions injection."
        return 0
    fi

    local -a AGENTS=($agents_str)
    log "Agents: ${AGENTS[*]}"

    # Discover all .md files in shared dir
    local -a md_files=()
    while IFS= read -r -d '' md; do
        md_files+=("$md")
    done < <(find "$SHARED_DIR" -maxdepth 1 -name "*.md" -type f -print0 2>/dev/null || true)

    if [[ ${#md_files[@]} -eq 0 ]]; then
        log "No .md files found in ${SHARED_DIR}"
        return 0
    fi

    for md_file in "${md_files[@]}"; do
        local filename
        filename="$(basename "$md_file")"
        local frontmatter_agents
        frontmatter_agents="$(parse_frontmatter_agents "$md_file")"

        # Determine which agents this file targets
        local -a target_agents=()
        if [[ "$frontmatter_agents" == "all" ]]; then
            target_agents=("${AGENTS[@]}")
        else
            for fa in $frontmatter_agents; do
                for a in "${AGENTS[@]}"; do
                    if [[ "$fa" == "$a" ]]; then
                        target_agents+=("$a")
                        break
                    fi
                done
            done
        fi

        if [[ ${#target_agents[@]} -eq 0 ]]; then
            log "Skipping ${filename}: no matching agents (${frontmatter_agents})"
            continue
        fi

        log "Injecting ${filename} into: ${target_agents[*]}"

        if [[ "$DRY_RUN" == "true" ]]; then
            log "  [dry-run] Would inject ${filename} into ${target_agents[*]}"
            continue
        fi

        # Inject into each target agent
        for agent in "${target_agents[@]}"; do
            inject_into_agent "$md_file" "$agent"
        done
    done

    log "Custom instructions applied."
}

inject_into_agent() {
    local md_file="$1"
    local agent="$2"
    local filename
    filename="$(basename "$md_file")"
    local block_id
    block_id="$(basename "$filename" .md | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"

    local start_marker="<!-- ai-coding-stack:${block_id}:start -->"
    local end_marker="<!-- ai-coding-stack:${block_id}:end -->"

    local custom_text
    custom_text="$(cat "$md_file")"
    local custom_block="${start_marker}

${custom_text}

${end_marker}"

    case "$agent" in
        kimi)
            inject_into_text_file "$KIMI_TARGET" "$custom_block" "$start_marker" "$end_marker"
            ;;
        opencode)
            inject_opencode "$md_file" "$custom_block" "$start_marker" "$end_marker"
            ;;
        pi)
            inject_into_text_file "$PI_TARGET" "$custom_block" "$start_marker" "$end_marker"
            ;;
        *)
            warn "Unknown agent '${agent}' — skipping ${filename}"
            ;;
    esac
}

inject_into_text_file() {
    local target="$1"
    local custom_block="$2"
    local start_marker="$3"
    local end_marker="$4"

    if [[ ! -f "$target" ]]; then
        echo "  [!] ${target} does not exist, skipping"
        return 0
    fi

    # Backup before modify
    backup_file "$target"

    local content
    content="$(cat "$target")"

    python3 - "$target" "$content" "$custom_block" "$start_marker" "$end_marker" <<'PY'
import json
import os
import re
import sys

target = sys.argv[1]
content = sys.argv[2]
custom_block = sys.argv[3]
start_marker = sys.argv[4]
end_marker = sys.argv[5]

pattern = re.compile(re.escape(start_marker) + ".*?" + re.escape(end_marker), re.DOTALL)
new_content = pattern.sub(custom_block.strip(), content)

if new_content == content and custom_block.strip() not in content:
    if not content.endswith("\n"):
        content += "\n"
    new_content = content + "\n" + custom_block.strip() + "\n"

with open(target, "w") as f:
    f.write(new_content)

print(f"  [ok] Injected into {target}")
PY
}

inject_opencode() {
    local md_file="$1"
    local custom_block="$2"
    local start_marker="$3"
    local end_marker="$4"

    if [[ ! -f "$OPENCODE_CONFIG" ]]; then
        echo "  [!] ${OPENCODE_CONFIG} does not exist, skipping opencode injection"
        return 0
    fi

    # Backup before modify
    backup_file "$OPENCODE_CONFIG"

    python3 - "$OPENCODE_CONFIG" "$custom_block" "$start_marker" "$end_marker" <<'PY'
import json
import os
import re
import sys

config_path = sys.argv[1]
custom_block = sys.argv[2]
start_marker = sys.argv[3]
end_marker = sys.argv[4]

with open(config_path, "r") as f:
    config = json.load(f)

default_agent_name = config.get("default_agent", "gentle-orchestrator")
agent = config.get("agent", {}).get(default_agent_name)
if not agent:
    print(f"  [!] Default agent '{default_agent_name}' not found in opencode.json")
    sys.exit(0)

prompt = agent.get("prompt", "")
pattern = re.compile(re.escape(start_marker) + ".*?" + re.escape(end_marker), re.DOTALL)
new_prompt = pattern.sub(custom_block.strip(), prompt)

if new_prompt == prompt and custom_block.strip() not in prompt:
    sep = "\n\n" if prompt and not prompt.endswith("\n") else "\n"
    new_prompt = prompt + sep + custom_block.strip() + "\n"

agent["prompt"] = new_prompt

with open(config_path, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"  [ok] Injected into opencode.json (agent: {default_agent_name})")
PY
}

backup_file() {
    local path="$1"
    local backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$path" "$backup"
    echo "  [backup] ${backup}"
}

# Parse --agents, --yes, --dry-run arguments
AGENTS=()
AUTO_YES=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agents)
                if [[ $# -lt 2 ]]; then
                    echo "ERROR: --agents requires a value" >&2
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
            *)
                echo "ERROR: Unknown argument: $1" >&2
                exit 1
                ;;
        esac
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    apply_custom_instructions
fi
