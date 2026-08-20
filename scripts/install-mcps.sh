#!/usr/bin/env bash
# Install MCPs declared in config/mcp-manifest.yaml.
#   1. Installs the server binary/tool (check_cmd / install_cmd)
#   2. Optionally registers the server in Pi's MCP config (pi_mcp_json)
# Idempotent: skips MCPs already present. Failures are non-critical (warn-and-continue).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$REPO_ROOT/config/mcp-manifest.yaml"

DRY_RUN="${DRY_RUN:-false}"

log() {
    echo "==> $*"
}

warn() {
    echo "WARNING: $*" >&2
}

# Parses the manifest and processes MCP entries sequentially.
# Binary installs run first; Pi mcp.json registration runs at the end.
install_mcps() {
    if [[ ! -f "$MANIFEST" ]]; then
        log "No MCP manifest found at ${MANIFEST}; skipping MCP installation"
        return 0
    fi

    log "Installing MCPs from ${MANIFEST}..."

    # Parse manifest using Python inline (YAML parsing is non-trivial in pure bash)
    python3 - "$MANIFEST" "${DRY_RUN}" "${REPO_ROOT}" <<'PY'
import json
import os
import subprocess
import sys

manifest_path = sys.argv[1]
dry_run = sys.argv[2] == "true"
repo_root = sys.argv[3]

# Minimal YAML list-of-dicts parser (sufficient for our manifest format)
def parse_manifest(path):
    mcps = []
    current = {}
    with open(path, "r") as f:
        for line in f:
            stripped = line.rstrip()
            # New list item
            if stripped.startswith("  - name:"):
                if current:
                    mcps.append(current)
                current = {"name": stripped.split(":", 1)[1].strip()}
            elif stripped.startswith("    "):
                if ":" in stripped:
                    key, val = stripped.split(":", 1)
                    val = val.strip()
                    # Strip surrounding quotes; otherwise sh -c treats the whole
                    # quoted string as one command name -> exit 127.
                    if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
                        val = val[1:-1]
                    current[key.strip()] = val
            elif stripped.startswith("#") or stripped == "":
                continue
            else:
                # Top-level key (like "mcps:") — skip
                pass
    if current:
        mcps.append(current)
    return mcps


def upsert_pi_mcps(pi_mcps):
    """Register MCP servers in Pi's mcp.json, preserving unrelated keys/servers."""
    agent_dir = os.environ.get("PI_CODING_AGENT_DIR") or os.path.expanduser("~/.pi/agent")
    config_path = os.path.join(agent_dir, "mcp.json")

    print(f"-> Registering MCP servers in Pi config: {config_path}")

    cfg = {}
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            cfg = json.load(f)
    servers = cfg.setdefault("mcpServers", {})

    changed = False
    for name, entry in pi_mcps.items():
        if servers.get(name) == entry:
            print(f"  [ok] Pi MCP '{name}' already configured, skipping")
            continue
        servers[name] = entry
        changed = True
        print(f"  [ok] Pi MCP '{name}' registered")

    if not changed:
        return
    if dry_run:
        print("  [dry-run] Would write updated Pi MCP config")
        return

    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("  [ok] Pi MCP config written")


try:
    mcps = parse_manifest(manifest_path)
except Exception as e:
    print(f"WARNING: Failed to parse MCP manifest: {e}")
    sys.exit(0)

if not mcps:
    print("No MCPs declared in manifest.")
    sys.exit(0)

pi_mcps = {}

for mcp in mcps:
    name = mcp.get("name", "unknown")
    check_cmd = mcp.get("check_cmd", "")
    install_cmd = mcp.get("install_cmd", "")
    description = mcp.get("description", "")
    pi_mcp_json = mcp.get("pi_mcp_json", "")
    pi_mcp_name = mcp.get("pi_mcp_name", name)

    display = f"{name}" + (f" ({description})" if description else "")
    print(f"-> Checking {display}...")

    # Collect Pi registration entries regardless of binary install state
    if pi_mcp_json:
        try:
            pi_mcps[pi_mcp_name] = json.loads(pi_mcp_json.replace("{REPO_ROOT}", repo_root))
        except json.JSONDecodeError as e:
            print(f"  [!] Invalid pi_mcp_json for {name}: {e}")

    # Check if already installed
    if check_cmd:
        try:
            subprocess.run(check_cmd, shell=True, check=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"  [ok] {name} already installed, skipping")
            continue
        except subprocess.CalledProcessError:
            pass

    if not install_cmd:
        if not check_cmd:
            print(f"  [-] {name}: no check_cmd/install_cmd (Pi registration only)")
        continue

    if dry_run:
        print(f"  [dry-run] Would run: {install_cmd}")
        continue

    # Attempt install (non-critical: warn on failure)
    print(f"  Installing {name}: {install_cmd}")
    try:
        subprocess.run(install_cmd, shell=True, check=True)
        print(f"  [ok] {name} installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"  [!] {name} install failed (non-critical): {e}")

if pi_mcps:
    try:
        upsert_pi_mcps(pi_mcps)
    except Exception as e:
        print(f"  [!] Pi MCP registration failed (non-critical): {e}")

PY

    log "MCP installation step complete."
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_mcps
fi
