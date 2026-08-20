#!/usr/bin/env bash
# Prints MCP request headers (JSON) for the Obsidian Local REST API plugin.
# The API key is read at runtime from the plugin config, so no secret lives here.
# Override the vault path with OBSIDIAN_VAULT if needed.
set -euo pipefail

VAULT="${OBSIDIAN_VAULT:-$HOME/Nextcloud/Documents/Obsidian Vault}"
DATA_JSON="$VAULT/.obsidian/plugins/obsidian-local-rest-api/data.json"

python3 - "$DATA_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], "r") as f:
    api_key = json.load(f)["apiKey"]

print(json.dumps({"Authorization": f"Bearer {api_key}"}))
PY
