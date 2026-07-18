# ai-coding-stack

Repositorio personal para respaldar y reinstalar rápidamente mi stack de herramientas de coding agents:

- [Kimi Code CLI](https://www.kimi.com/)
- [OpenCode](https://opencode.ai/)
- [pi](https://github.com/earendil-works/pi-coding-agent)

## Propósito

- Centralizar configuraciones comunes.
- Mantener apuntadores a repositorios relacionados.
- Automatizar la instalación del entorno en una nueva máquina.
- Instalar automáticamente herramientas complementarias (`uv`/`uvx` y `markitdown-mcp`) y reaplicar mis instrucciones personalizadas después de cada `gentle-ai sync`.

## Estructura

```text
.
├── install.sh                           # Punto de entrada: ejecuta scripts/install.sh (acepta --agents opcional)
├── scripts/
│   ├── install.sh                       # Instala Homebrew, gentle-ai, uv/uvx, markitdown-mcp y sincroniza agentes
│   └── apply-custom-instructions.sh     # Inyecta custom-instructions.md en cada agente
├── config/
│   ├── .gitkeep                         # Preserva el directorio en git
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
- Conexión a internet

> Nota: `uv`/`uvx` y `markitdown-mcp` se instalan automáticamente mediante `install.sh`. `ssh-homelab` no se instala automáticamente; requiere configuración manual.

## Uso

```bash
git clone https://github.com/geme/ai-coding-stack.git ~/Documentos/Github/ai-coding-stack
cd ~/Documentos/Github/ai-coding-stack
./install.sh [--agents agente1,agente2,...]
```

`install.sh` hace lo siguiente:

1. Valida/instala Homebrew.
2. Instala `gentle-ai` via Homebrew.
3. Instala `uv`/`uvx` y `markitdown-mcp` (el MCP de Obsidian se ejecuta via `uvx mcp-obsidian`, no instala el escritorio de Obsidian).
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
```

> `ssh-homelab` no se instala automáticamente. Para usarlo, configúralo manualmente siguiendo la documentación del MCP.

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
