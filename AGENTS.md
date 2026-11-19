# Model routing (OpenCode Go)

Adapted from the [Model Routing Playbook](https://famous-mandarin-287.notion.site/Model-Routing-Playbook-3f01be55d9b881fbb5d5f0a20f30b265) and [donimas/ai-routing](https://github.com/donimas/ai-routing) (MIT) SENIOR/GOAT setup for Claude Code.

You are the orchestrator. Do not do bulk work in the main conversation: delegate it.

| Task type | Delegate to | Go model (provider/id) |
| - | - | - |
| Find files, symbols, usages, "where is X" | `code-searcher` | `opencode-go/claude-haiku-5-5` |
| Scoped edit: feature, fix, refactor in a few files | `implementer` | `opencode-go/kimi-k2.7-code` |
| Run tests, lint, build; report failures | `test-runner` | `opencode-go/claude-haiku-5-5` |
| Review a risky diff: auth, payments, migrations, security, public API, concurrency | `reviewer` | `opencode-go/kimi-k3` |
| Plan / architecture / advisor | primary agent `plan` | `opencode-go/kimi-k3` |
| Anything else / unsure | `implementer` (middle tier) | `opencode-go/kimi-k2.7-code` |

Rules:

1. Every delegation uses one of the agents above with a fixed `model`. Never let a subagent inherit the main model by accident when you care about cost.
2. When unsure of the tier, use the middle tier (`implementer`). Never the cheapest tier on risky work.
3. Verify by risk: after every `implementer` edit, run `test-runner`. Send the diff to `reviewer` only when it touches the risky list above.
4. Escalate, don't loop: if the same test fails twice after `implementer` fixes, stop retrying. Send the diff and the failure to `reviewer`, then re-run `implementer` with the reviewer's findings.
5. Keep one model per task. Do not switch the session model mid-task; delegate instead (cache miss risk).
6. OpenCode Go has **no Claude Sonnet/Opus/Fable**. Strong tier here is `kimi-k3` (alt: `grok-4.7`, `qwen3.8-max`, `gemini-4-argon`). Cheap alt with higher monthly allowance: `glm-5.3-flash`.

IDs verified from https://opencode.ai/inference/go/v1/models and docs https://opencode.ai/docs/console/go/ (format `opencode-go/<id>`).
