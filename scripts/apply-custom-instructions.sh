#!/usr/bin/env bash
set -euo pipefail

# Inyecta custom-instructions.md en los agentes registrados en ~/.gentle-ai/state.json.
# Solo modifica agentes que estén presentes en state.json: kimi, opencode, pi.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTOM_INSTRUCTIONS="$REPO_ROOT/config/shared/custom-instructions.md"
STATE_FILE="$HOME/.gentle-ai/state.json"
START_MARKER="<!-- ai-coding-stack:custom-instructions:start -->"
END_MARKER="<!-- ai-coding-stack:custom-instructions:end -->"

if [[ ! -f "$CUSTOM_INSTRUCTIONS" ]]; then
    echo "ERROR: No se encontró $CUSTOM_INSTRUCTIONS" >&2
    exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: No se encontró $STATE_FILE. Asegurate de que ~/.gentle-ai/state.json existe (corre ./install.sh primero)." >&2
    exit 1
fi

CUSTOM_TEXT="$(cat "$CUSTOM_INSTRUCTIONS")"
CUSTOM_BLOCK="$START_MARKER

$CUSTOM_TEXT

$END_MARKER"

python3 - "$STATE_FILE" "$CUSTOM_BLOCK" <<'PY'
import json
import os
import re
import sys

state_file = sys.argv[1]
custom_block = sys.argv[2]
start_marker = "<!-- ai-coding-stack:custom-instructions:start -->"
end_marker = "<!-- ai-coding-stack:custom-instructions:end -->"

with open(state_file, "r") as f:
    state = json.load(f)

agents = state.get("installed_agents", [])
print(f"Agentes registrados en gentle-ai: {', '.join(agents)}")


def backup_file(path: str):
    backup = f"{path}.bak.{__import__('datetime').datetime.now().strftime('%Y%m%d-%H%M%S')}"
    with open(path, "r") as f:
        data = f.read()
    with open(backup, "w") as f:
        f.write(data)
    print(f"  [backup] {backup}")


def inject_into_text(path: str, block: str) -> bool:
    if not os.path.isfile(path):
        print(f"  [!] No existe {path}, se omite")
        return False

    backup_file(path)

    with open(path, "r") as f:
        content = f.read()

    pattern = re.compile(re.escape(start_marker) + ".*?" + re.escape(end_marker), re.DOTALL)
    new_content = pattern.sub(block.strip(), content)

    if new_content == content and block.strip() not in content:
        # No había bloque previo; añadir al final
        if not content.endswith("\n"):
            content += "\n"
        new_content = content + "\n" + block.strip() + "\n"

    with open(path, "w") as f:
        f.write(new_content)

    print(f"  [ok] Inyectado en {path}")
    return True


def inject_opencode():
    path = os.path.expanduser("~/.config/opencode/opencode.json")
    if not os.path.isfile(path):
        print("  [!] No existe ~/.config/opencode/opencode.json")
        return

    backup_file(path)

    with open(path, "r") as f:
        config = json.load(f)

    default_agent = config.get("default_agent", "gentle-orchestrator")
    agent = config.get("agent", {}).get(default_agent)
    if not agent:
        print(f"  [!] No se encontró el agente default '{default_agent}' en opencode.json")
        return

    prompt = agent.get("prompt", "")
    pattern = re.compile(re.escape(start_marker) + ".*?" + re.escape(end_marker), re.DOTALL)
    new_prompt = pattern.sub(custom_block.strip(), prompt)

    if new_prompt == prompt and custom_block.strip() not in prompt:
        sep = "\n\n" if prompt and not prompt.endswith("\n") else "\n"
        new_prompt = prompt + sep + custom_block.strip() + "\n"

    agent["prompt"] = new_prompt

    with open(path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"  [ok] Inyectado en opencode.json (agente: {default_agent})")


if "kimi" in agents:
    print("-> Aplicando custom instructions a Kimi Code CLI")
    inject_into_text(os.path.expanduser("~/.kimi/KIMI.md"), custom_block)

if "opencode" in agents:
    print("-> Aplicando custom instructions a OpenCode")
    inject_opencode()

if "pi" in agents:
    print("-> Aplicando custom instructions a Pi")
    inject_into_text(os.path.expanduser("~/.pi/agent/APPEND_SYSTEM.md"), custom_block)

print("==> Custom instructions aplicadas.")
PY
