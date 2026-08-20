# ai-coding-stack

Repositorio personal para respaldar y reinstalar rápidamente mi stack de herramientas de coding agents:

- [Kimi Code CLI](https://www.kimi.com/)
- [OpenCode](https://opencode.ai/)
- [pi](https://github.com/earendil-works/pi-coding-agent)

## Propósito

- Centralizar configuraciones comunes.
- Mantener apuntadores a repositorios relacionados.
- Automatizar la instalación del entorno en una nueva máquina.
- Instalar y registrar en Pi los MCPs declarados en `config/mcp-manifest.yaml` (markitdown, obsidian) y reaplicar mis instrucciones personalizadas después de cada `gentle-ai sync`.

## Estructura

```text
.
├── install.sh                           # Punto de entrada: ejecuta scripts/install.sh (acepta --agents opcional)
├── scripts/
│   ├── install.sh                       # Orquesta: herramientas (Homebrew, gentle-ai, engram), MCPs, fuentes y sync de agentes
│   ├── install-mcps.sh                  # Instala binarios de MCPs y los registra en Pi (~/.pi/agent/mcp.json)
│   ├── obsidian-auth.sh                 # Headers de auth para el MCP de Obsidian (lee la API key del vault en runtime)
│   └── apply-custom-instructions.sh     # Inyecta custom-instructions.md en cada agente
├── config/
│   ├── .gitkeep                         # Preserva el directorio en git
│   ├── mcp-manifest.yaml                # MCPs declarados: binario (check_cmd/install_cmd) + registro en Pi (pi_mcp_json)
│   └── shared/
│       └── custom-instructions.md       # Instrucciones personalizadas: Obsidian + MarkItDown
├── repos.md                             # Apuntadores a repos importantes
├── .gitignore                           # Exclusiones de git
└── README.md                            # Este archivo
```

## Requisitos previos

- `bash`
- `git`
- `curl`
- `python3`
- `uv` (lo usa `install-mcps.sh` para instalar `markitdown-mcp`):
  `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Conexión a internet

> Nota: ningún script instala `uv` automáticamente; es prerequisito manual. `ssh-homelab` tampoco se instala; requiere configuración manual.

## Uso

```bash
git clone https://github.com/GemeWolf/ai-coding-stack.git ~/Documentos/Github/ai-coding-stack
cd ~/Documentos/Github/ai-coding-stack
./install.sh [--agents agente1,agente2,...]
```

`install.sh` hace lo siguiente:

1. Valida/instala Homebrew.
2. Instala `gentle-ai` (tap Homebrew) y `engram` (release verificado por checksum).
3. Instala los MCPs declarados en `config/mcp-manifest.yaml` via `install-mcps.sh`:
   - `markitdown-mcp`: instala el binario con `uv tool install` y lo registra en Pi como servidor stdio (`directTools`).
   - `obsidian`: lo registra en Pi contra el plugin Local REST API (`http://127.0.0.1:27123/mcp/`); `scripts/obsidian-auth.sh` lee la API key del vault en runtime, sin secretos en el repo.

   Prerequisitos del MCP de obsidian (una sola vez, en Obsidian de escritorio):
   1. Instalar el plugin community **Local REST API**.
   2. En sus settings, habilitar **Enable Non-encrypted (HTTP) Server** (`enableInsecureServer`, default: apagado) — el endpoint MCP vive en el puerto HTTP `27123`.
4. Registra los agentes `kimi`, `opencode` y `pi` (o los indicados con `--agents`) en `~/.gentle-ai/state.json`.
5. Corre `gentle-ai sync` para descargar skills, SDD agents, prompts, etc.
6. Ejecuta `apply-custom-instructions.sh` para inyectar `config/shared/custom-instructions.md` en cada agente registrado.

El flag opcional `--agents` permite sobrescribir la lista por defecto. Ejemplo:

```bash
./install.sh --agents kimi,opencode
```

> Nota: este repositorio es personal. Las rutas y preferencias están adaptadas a mi workspace en `/home/geme`.

## Verificación

Comprueba que la instalación terminó bien:

```bash
which gentle-ai
which uv
which uvx
which markitdown-mcp
ls ~/.gentle-ai/state.json
ls ~/.kimi/KIMI.md
ls ~/.config/opencode/opencode.json
ls ~/.pi/agent/APPEND_SYSTEM.md

# MCPs registrados en Pi (markitdown y obsidian deben aparecer):
grep -o '"markitdown"\|"obsidian"' ~/.pi/agent/mcp.json
# y dentro de Pi: /mcp muestra ambos servidores (obsidian requiere Obsidian abierto)
```

> `ssh-homelab` no se instala automáticamente. Para usarlo, configúralo manualmente siguiendo la documentación del MCP.

## MCPs en Pi

`scripts/install-mcps.sh` es la fuente de verdad para los MCPs personalizados. Por cada entrada de `config/mcp-manifest.yaml`:

1. Instala el binario si declara `check_cmd`/`install_cmd` (idempotente).
2. Si declara `pi_mcp_json`, registra/actualiza el servidor en la config MCP de Pi (`$PI_CODING_AGENT_DIR/mcp.json` si está definida, si no `~/.pi/agent/mcp.json`), preservando servidores ajenos. `{REPO_ROOT}` se expande a la ruta absoluta del repo.

```bash
DRY_RUN=true bash scripts/install-mcps.sh   # simular sin escribir
bash scripts/install-mcps.sh                # aplicar
```

> Tras registrar MCPs nuevos, reinicia Pi o usa `/reload` para cargarlos.

## Actualización / re-aplicación

Después de un `gentle-ai sync` que pueda sobrescribir configuraciones, vuelve a inyectar las custom instructions:

```bash
cd ~/Documentos/Github/ai-coding-stack
./scripts/apply-custom-instructions.sh
```

## Custom instructions

Las instrucciones personalizadas viven en un solo archivo (`config/shared/custom-instructions.md`) y se inyectan en:

- `~/.kimi/KIMI.md` (Kimi Code CLI)
- `~/.config/opencode/opencode.json` -> prompt del agente por defecto (OpenCode)
- `~/.pi/agent/APPEND_SYSTEM.md` (pi)

El script usa delimitadores (`<!-- ai-coding-stack:custom-instructions:start/end -->`) para poder re-inyectar sin duplicar contenido.
