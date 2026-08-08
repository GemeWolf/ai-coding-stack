#!/usr/bin/env bash
# Auto-detect installed coding agents by binary presence and config directory scan.
# Outputs a comma-separated agent list to stdout (empty if none detected).

set -euo pipefail

detect_agents() {
    local agents=()

    # Kimi Code CLI: binary + ~/.kimi/ config dir
    if command -v kimi &>/dev/null && [[ -d "${HOME}/.kimi" ]]; then
        agents+=("kimi")
    fi

    # OpenCode: binary + ~/.config/opencode/ config dir
    if command -v opencode &>/dev/null && [[ -d "${HOME}/.config/opencode" ]]; then
        agents+=("opencode")
    fi

    # pi: binary + ~/.pi/ config dir
    if command -v pi &>/dev/null && [[ -d "${HOME}/.pi" ]]; then
        agents+=("pi")
    fi

    # Output comma-separated list
    local IFS=","
    echo "${agents[*]:-}"
}

# Run detection if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_agents
fi
