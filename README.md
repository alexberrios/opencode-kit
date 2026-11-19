# OpenCode Kit

Kit para dejar el ruteo de modelos de OpenCode Go en cualquier proyecto, con un comando.

OpenCode arranca con un orquestador que no hace el trabajo pesado en la conversación principal: lo manda a agentes con un modelo fijo. El modelo caro se usa solo cuando el cambio lo merece.

El diseño está basado en [donimas/ai-routing](https://github.com/donimas/ai-routing) (MIT, Copyright 2026 donimas), la versión para Claude Code del [Model Routing Playbook](https://famous-mandarin-287.notion.site/Model-Routing-Playbook-3f01be55d9b881fbb5d5f0a20f30b265). Acá está adaptado a los modelos de OpenCode Go. Las notas y las fuentes están en `NOTES.md`.

## Qué se copia al proyecto

- `opencode.json` — modelos, agentes y comandos
- `AGENTS.md` — reglas de ruteo que lee OpenCode
- `.opencode/agents/` — `code-searcher`, `implementer`, `test-runner` y `reviewer`

`NOTES.md` se queda en este repo. No se instala en el proyecto.

## Ruteo

| Tarea | Agente | Modelo | Nivel |
| - | - | - | - |
| Buscar archivos, símbolos, "dónde está X" | `code-searcher` | `opencode-go/claude-haiku-5-5` | barato |
| Correr tests, lint o build y reportar fallas | `test-runner` | `opencode-go/claude-haiku-5-5` | barato |
| Editar algo acotado (feature, fix, refactor chico) | `implementer` | `opencode-go/kimi-k2.7-code` | medio |
| Revisar un diff riesgoso: auth, pagos, migraciones, seguridad, API pública, concurrencia. También si los tests fallaron dos veces | `reviewer` | `opencode-go/kimi-k3` | fuerte |

Si no está claro el nivel, se usa el del medio (`implementer`). El barato no se usa en trabajo riesgoso. Plan y arquitectura van al agente `plan`, también en `opencode-go/kimi-k3`.

Hay comandos opcionales: `/route-lookup`, `/route-edit`, `/route-test` y `/route-review`.

## Requisitos

- [OpenCode](https://opencode.ai/) con OpenCode Go conectado (`/connect` y la API key).
- macOS o Linux con bash, o Windows con PowerShell 5.1 o 7.

Corre el instalador en la raíz del proyecto. Ahí es donde OpenCode lee `opencode.json`.

## Instalar en Mac o Linux

Desde un clon local:

```bash
cd /ruta/al/proyecto
~/opencode-kit/install.sh
```

En una línea, si este repositorio es público:

```bash
cd /ruta/al/proyecto
curl -fsSL https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.sh | bash
```

## Instalar en Windows

Desde un clon local, en PowerShell:

```powershell
cd C:\ruta\al\proyecto
~\opencode-kit\install.ps1
```

Si Windows bloquea el script local:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ~\opencode-kit\install.ps1
```

En una línea, si este repositorio es público:

```powershell
cd C:\ruta\al\proyecto
irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1 | iex
```

El one-liner remoto solo funciona si el repo es público. `raw.githubusercontent.com` no entrega archivos de un repo privado. Si es privado, clónalo una vez y usa el script local:

```bash
gh repo clone alexberrios/opencode-kit ~/opencode-kit
cd /ruta/al/proyecto
~/opencode-kit/install.sh
```

En Windows, la misma idea: `gh repo clone alexberrios/opencode-kit $HOME\opencode-kit` y después `~\opencode-kit\install.ps1` dentro del proyecto.

## Si el proyecto ya tiene archivos

El instalador no reemplaza nada en silencio.

- Si el archivo no existe, lo copia.
- Si ya existe y es igual al del kit, lo deja igual.
- Si ya existe y es distinto, lo salta y avisa. Esto vale para `opencode.json`, `AGENTS.md` y los cuatro agentes.

Para reemplazarlos, `--force` en bash y `-Force` en PowerShell guardan la versión anterior en `.bak` (o `.bak.1`, `.bak.2`, … si ya había un backup) y recién ahí escriben la del kit.

```bash
~/opencode-kit/install.sh --force
curl -fsSL https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.sh | bash -s -- --force
```

```powershell
~\opencode-kit\install.ps1 -Force
```

`-Force` no viaja por el pipe de `irm | iex`. En remoto usa una de estas dos:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1))) -Force
$env:OPENCODE_KIT_FORCE = '1'; irm https://raw.githubusercontent.com/alexberrios/opencode-kit/main/install.ps1 | iex
```

## Actualizar un proyecto más adelante

Entra de nuevo a la raíz del proyecto y corre el mismo comando.

Sin `--force` / `-Force` solo completa lo que falte. Si ya tienes una copia vieja del kit, esa se queda: el script avisa y no la toca.

Con `--force` / `-Force` trae la versión actual del kit. Lo que había queda al lado, con el mismo nombre y `.bak`. Si editaste `opencode.json` o `AGENTS.md` a mano, revisa ese backup antes de borrarlo.

## Desinstalar

Borra estos archivos del proyecto:

- `opencode.json`
- `AGENTS.md`
- `.opencode/agents/code-searcher.md`
- `.opencode/agents/implementer.md`
- `.opencode/agents/reviewer.md`
- `.opencode/agents/test-runner.md`

Si `.opencode/agents` queda vacía, puedes borrar la carpeta. Las copias `.bak` son tuyas: bórralas, o vuelve atrás con `mv opencode.json.bak opencode.json` (en PowerShell, `Move-Item -Force opencode.json.bak opencode.json`). El instalador no toca el resto del repo.

## Licencia

MIT. Ver `LICENSE`. Conserva el aviso Copyright (c) 2026 donimas junto al de Alex Berríos.
