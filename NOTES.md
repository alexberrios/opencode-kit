# OpenCode Go × Model Routing Playbook — notas

## Fuentes
- Playbook Notion: https://famous-mandarin-287.notion.site/Model-Routing-Playbook-3f01be55d9b881fbb5d5f0a20f30b265 (autor @donimas, Oct 5 2026)
- Implementación Claude Code: https://github.com/donimas/ai-routing (MIT License, Copyright 2026 donimas)
- OpenCode Go: https://opencode.ai/docs/console/go/
- OpenCode agents/config: https://opencode.ai/docs/agents/ · https://opencode.ai/docs/config/
- Model IDs live: https://opencode.ai/inference/go/v1/models

## Qué aporta donimas/ai-routing
Es la implementación copy-paste del playbook para **Claude Code** (y un router API de ejemplo):
- `templates/.claude/agents/{code-searcher,implementer,test-runner,reviewer}.md` con `model` + `effort`
- `templates/CLAUDE.md` tabla de ruteo GOAT
- `templates/settings.json` (`sonnet` default, `advisorModel: opus`)
- Hook opcional `require-subagent-model.py`
- `examples/router.py` clasificador Haiku → Haiku/Sonnet/Opus (requiere `ANTHROPIC_API_KEY`)
- Licencia: **MIT**

El Notion y el repo son el mismo sistema (GOAT / AI LEVELS).

## Mapeo playbook → OpenCode Go

| Rol playbook | Claude Code | OpenCode Go (este repo) |
| - | - | - |
| lookup / code-searcher | haiku · low | `opencode-go/claude-haiku-5-5` |
| edit / implementer | sonnet · medium | `opencode-go/kimi-k2.7-code` |
| test-runner | haiku · low | `opencode-go/claude-haiku-5-5` |
| risky / reviewer | opus · high | `opencode-go/kimi-k3` (no hay Opus en Go) |
| default orchestrator | sonnet · medium | `opencode-go/kimi-k2.7-code` |
| advisor / plan | opus / opusplan | primary `plan` → `opencode-go/kimi-k3` |
| small_model / títulos | haiku | `opencode-go/claude-haiku-5-5` |

Alternativas verificadas (mismos IDs en la API Go):
- Cheap alto allowance: `opencode-go/glm-5.3-flash`, `opencode-go/deepseek-v4.1-flash`
- Mid: `opencode-go/qwen3.7-plus`, `opencode-go/glm-5.2`, `opencode-go/minimax-m3`
- Strong: `opencode-go/grok-4.7`, `opencode-go/qwen3.8-max`, `opencode-go/gemini-4-argon`, `opencode-go/deepseek-v4-pro`

## OpenCode Go — planes (docs oficiales)
- Go $10/mes · Go Plus $40/mes · Go Teams $20/miembro/mes
- Límites por modelo en $ de allowance (5h = 20%, semana = 50%, mes = 100%)
- Conectar: `/connect` → OpenCode Go → API key; elegir con `/models`
- Lista de modelos incluye open-weights + Haiku 5.5 + Grok 4.7 + GPT Luna + Gemini 4 Argon, etc. **Sin Sonnet/Opus/Fable.**

## Qué NO aplica o requiere otro proveedor
1. **Aliases haiku/sonnet/opus y effort frontmatter de Claude Code** — OpenCode usa `provider/model` y opcional `#variant`; effort Anthropic no está documentado para modelos Go → **no se puso `#low/#medium/#high`** (no verificado en Go).
2. **`advisorModel` / `/advisor` / `opusplan`** — no existen en OpenCode; se emula con agente primary `plan` en modelo strong.
3. **Hook PreToolUse `require-subagent-model.py`** — específico Claude Code; en OpenCode usar `permissions` en agentes y reglas en AGENTS.md.
4. **`examples/router.py`** — client Anthropic API + modelos Sonnet/Opus; para Go habría que reescribir contra `https://opencode.ai/inference/go/...` con IDs Go (no incluido aquí).
5. **Math de costo por token del playbook** — en Go pagas suscripción + allowance por modelo; la métrica útil es allowance gastado / tarea resuelta, no $ API Anthropic.
6. **Cascade con Stop hook** — no portado; usar test-runner + regla de escalación manual en AGENTS.md.
7. **Fable / Opus verdadero** — requieren Anthropic u otro provider fuera de Go (`anthropic/...` en el mismo opencode.json si tienes esa key).

## Cómo usar
1. Suscribirse a Go y `/connect` con la API key.
2. Copiar `opencode.json` y `AGENTS.md` a la raíz del proyecto (o `~/.config/opencode/`).
3. Arrancar OpenCode; el default es `build` en `kimi-k2.7-code`.
4. Comandos slash opcionales: `/route-lookup`, `/route-edit`, `/route-test`, `/route-review`.
