# Changelog

All notable changes to this fork are documented here. Versions are the fork's own
release **tags** (`v1.0.x`), which are independent of the upstream
`livekit-plugins-google` package version.

> **How to read this:** each fork tag = a snapshot of upstream `livekit-plugins-google`
> at a specific version, **plus** the local patches listed under each entry. Pick the
> tag whose `livekit-agents` compatibility matches the version your project is pinned to
> (see [Which tag should I use?](#which-tag-should-i-use)).
>
> Descriptions below are derived from the actual `git diff` between consecutive tags.

## Compatibility matrix

| Fork tag | Upstream plugin base | `livekit` (SDK) | `livekit-agents` | pin in `pyproject.toml` |
| -------- | -------------------- | --------------- | ---------------- | ----------------------- |
| `v1.0.8` | 1.9.0                | 1.2.1           | 1.9.0            | `livekit-agents>=1.9.0,<1.10` |
| `v1.0.7` | 1.8.1                | 1.1.18          | 1.8.1            | `livekit-agents>=1.8.1,<1.9` |
| `v1.0.6` | 1.8.0                | 1.1.17          | 1.8.0            | `livekit-agents>=1.8.0,<1.9` |
| `v1.0.5` | 1.6.7                | 1.1.13          | 1.6.7            | `livekit-agents>=1.6.7` |
| `v1.0.4` | 1.6.4                | 1.1.12          | 1.6.4            | `livekit-agents>=1.6.4` |
| `v1.0.3` | 1.5.17               | 1.1.8           | 1.5.17           | `livekit-agents>=1.5.17`|
| `v1.0.2` | 1.5.4                | 1.1.5           | 1.5.4            | `livekit-agents>=1.5.4` |
| `v1.0.1` | —                    | not documented  | ≥ 1.5.0          | `livekit-agents>=1.5.0` |
| `v1.0.0` | —                    | not documented  | ≥ 1.5.0          | `livekit-agents>=1.5.0` |

The `livekit` (SDK) column was only tracked from `v1.0.2` onward. For `v1.0.0`/`v1.0.1`,
only the `livekit-agents>=1.5.0` floor from `pyproject.toml` is known.

The fork tracks `livekit-agents` closely: the plugin depends on internal
`livekit-agents` APIs, so a fork tag must be paired with the matching
`livekit-agents` version above.

---

## v1.0.8 — sync to upstream plugin 1.9.0 (livekit-agents 1.9.0)

**Compatibility:** `livekit==1.2.1`, `livekit-api>=1.2.2`, `livekit-agents==1.9.0`.
**Base:** upstream `livekit-plugins-google` 1.9.0 (synced from 1.8.1).

**Why:** Gemini 3.8 Live (`gemini-3.8-live`, `gemini-3.8-live-extended-thinking`). Upstream
added both in 1.8.2 for the Gemini API, and `gemini-3.8-live` on Vertex AI in 1.8.5, with an
error when `thinking_level` is set on `gemini-3.8-live` (use the extended-thinking model).
Extended thinking stays Gemini-API only.

**Dependencies (upstream 1.9.0's):** `google-genai>=3.2.0`, `httpx2>=2.12,<3`, and
`livekit-agents>=1.9.0,<1.10`. livekit-agents 1.8.7+ moves openai to 3.x, mcp to 2.x and
anthropic to 1.x, all on `httpx2`.

**Dropped: the gemini-3.1 `generate_reply` patch.** Upstream now marks every model's chat
context mutable and, for the models in `MODELS_WITHOUT_REPLY_PLACEHOLDER` (3.1, 3.8), sends
no `"."` placeholder turn and wraps `instructions` in a user turn. Our realtime-text-input
route is superseded.

**Changed: the stale `model_turn` guard now covers 3.8.** A tool call marks the turn
finished for the models upstream lists in `MODELS_WITHOUT_REPLY_PLACEHOLDER` (was: any model
name containing `"3.1"`). Without it, on 3.8 the guard would drop the model's reply to the
tool result.

**Kept, unchanged:** `use_parameters_json_schema=True` for realtime tools, keeping `default`
in `simplify()`, and emitting recoverable connection errors after the backoff. Upstream 1.9.0
still sends `use_parameters_json_schema=False`, still drops `default`, and still emits
before the sleep.

The repository moved from `Darshak03/livekit-google-plugin` to
`unify-apps/livekit-google-plugin`; older tags are the same commits.

---

## v1.0.7 — sync to upstream plugin 1.8.1 (livekit-agents 1.8.1)

**Compatibility:** `livekit==1.1.18`, `livekit-agents==1.8.1`.
**Base:** upstream `livekit-plugins-google` 1.8.1 (synced from 1.8.0).

**Upstream 1.8.1 is 1.8.0 plus exactly one change:** livekit/agents#6000,
*"skip context replay on resumed realtime sessions"* (`realtime_api.py` only, +95/-32).
Nothing else in the package moved — `llm.py`, `stt.py`, `tts.py`, `utils.py`, `beta/`
are byte-identical to 1.8.0. `pyproject.toml` bumps its own floor to
`livekit-agents>=1.8.1`, which is why this fork's pin moves to `>=1.8.1,<1.9`.

**One fork patch was fixed upstream and is now dropped.** The stash-and-replay of
in-flight tool results across an `update_tools` restart (`_pending_tool_result`) is
gone. Upstream #6000 solves the same failure through a different mechanism: the
plugin always reconnects with the last session resumption handle, so it now skips
the full history replay and sends only the diff between the chat context that handle
stands for and the current one. A tool result that was queued and dropped by the
restart — or dequeued and mid-send when the socket died — is still marked unsent, so
the handle's snapshot leaves it out and the reconnect diff re-sends it as a tool
response to the session that still holds the call open.

Keeping our stash on top of that would have delivered the same result twice. The
upstream PR that mirrored our patch (livekit/agents#7153) was closed unmerged one
minute after #6000 landed, for the same reason.

Side effect worth knowing: #6000 also fixes history *duplication*. Before it, every
reconnect — including the `update_tools` restart after every tool call — replayed the
local chat context onto a session that already held it.

**Fork patches in this tag** (unchanged from v1.0.6 unless noted):
- **Realtime tool params preserve pre-filled values** — `use_parameters_json_schema=True`
  in `realtime/realtime_api.py` and `default` retained in `_GeminiJsonSchema.simplify()`
  (`utils.py`). Same rationale and same caveat for older Live models as v1.0.5.
- **gemini-3.1 Live support.** 3.1 reports `mutable_chat_context=False`, which upstream
  still treats as "no agent-initiated turns at all" — `generate_reply` raises
  `RealtimeError`, so greetings, handoffs and post-tool prompts never happen. 3.1 does
  honour `LiveClientRealtimeInput(text=...)`, so `generate_reply` is routed through that
  on 3.1 and keeps the placeholder-user-turn path on 2.x. **Fixed since v1.0.6:**
  `instructions` is `NOT_GIVEN` for most agent-initiated turns (`agent_activity` passes
  `instructions or NOT_GIVEN`), and the 3.1 branch was putting that sentinel on the wire
  instead of text; it now falls back to the same `"."` nudge the 2.x path uses. The
  `_generation_completed` flag that drops `model_turn` parts streamed after a turn is
  finalized is carried forward unchanged.
- **Recoverable connection errors emitted after the retry backoff.**
  `_emit_error(recoverable=True)` fires after the reconnect sleep, not before, so a
  recoverable blip does not tear the agent session down mid-reconnect.

**`scripts/verify.sh`:** the `_pending_tool_result` check is removed along with the
patch, and the gemini-3.1 check now greps the `NOT_GIVEN` fallback rather than the old
`LiveClientRealtimeInput(text=instructions)` line.

---

## v1.0.6 — sync to upstream plugin 1.8.0 (livekit-agents 1.8.0)

**Compatibility:** `livekit==1.1.17`, `livekit-agents==1.8.0`.
**Base:** upstream `livekit-plugins-google` 1.8.0 (synced from 1.6.7).

**This sync is required, not optional.** `livekit-agents` 1.8.0 calls
`llm.session(turn_detection_disabled=...)` unconditionally
(`voice/agent_activity.py:1086`) and upstream widened `RealtimeModel.session()` to
match. `v1.0.5` still declares `def session(self)`, so on agents 1.8.0 **every**
realtime session creation raises `TypeError`. There is no configuration that avoids
this; `v1.0.5` and `livekit-agents==1.8.0` cannot be paired.

**No fork patch was fixed upstream.** Diffed 1.6.7 against 1.8.0 before re-applying:
`schema.pop("default", None)` (`utils.py:153`), `use_parameters_json_schema=False`
(`realtime_api.py:1187`), the `generate_reply` `mutable_chat_context` guard
(`realtime_api.py:776`) and the pre-backoff `_emit_error` are all still present in
1.8.0, and no tool-result replay exists. All four patches carried forward unchanged
in behaviour.

**Fork patches in this tag** (unchanged from v1.0.5 unless noted):
- **Realtime tool params preserve pre-filled values** — `use_parameters_json_schema=True`
  in `realtime/realtime_api.py` and `default` retained in `_GeminiJsonSchema.simplify()`
  (`utils.py`). Same rationale and same caveat for older Live models as v1.0.5.
- **Tool-result replay across `update_tools` restarts.** A result that lands while the
  Live session is reconnecting is written to a closing socket, so the model never sees
  an answer to its call and the conversation stalls silently. The result is held while
  `_session_should_close` is set and replayed on the new session; on the Gemini API path
  it is also restated as a user turn to trigger a generation, since the reconnected
  session has no memory of the originating call. Vertex keeps server-side history and
  needs no nudge.
- **gemini-3.1 Live support.** 3.1 reports `mutable_chat_context=False`, which upstream
  treats as "no agent-initiated turns at all" — `generate_reply` raises `RealtimeError`,
  so greetings, handoffs and post-tool prompts never happen. 3.1 does honour
  `LiveClientRealtimeInput(text=...)`, so `generate_reply` is routed through that on 3.1
  and keeps the placeholder-user-turn path on 2.x. `instructions` is often `NOT_GIVEN`
  (`agent_activity` passes `instructions or NOT_GIVEN`), so the 3.1 branch falls back to
  the same `"."` nudge the 2.x path uses rather than putting the sentinel on the wire. 3.1 also streams `model_turn` parts
  after a turn is finalized (most visibly after a tool call); upstream opens a fresh
  generation for them and replays stale audio, so a `_generation_completed` flag now
  tracks whether the turn is still open and drops the trailing parts.
- **Recoverable connection errors emitted after the retry backoff.**
  `_emit_error(recoverable=True)` fired *before* the reconnect sleep, so the consuming
  error handler tore the agent session down while the plugin was about to reconnect
  successfully. Moving the emit after the backoff lets a recoverable blip stay
  recoverable.

**Behaviour change vs v1.0.5:** the gemini-3.1 branches now test `"3.1" in model`
instead of the exact string `gemini-3.1-flash-live-preview`, matching how upstream
gates 3.1 itself (`mutable = "3.1" not in model`, `if "3.1" in model:`). Any 3.1 Live
model is covered, not just the one preview id.

**`pyproject.toml`:** the `livekit-agents` pin gains an upper bound
(`>=1.8.0,<1.9`). The unbounded `>=1.6.7` in v1.0.5 is precisely what let pip resolve
the fork onto an incompatible `livekit-agents` release with no warning — bump this
range in the same change as any future sync. Also picks up upstream's raised floors:
`google-genai>=2.13` (was `>=1.68`) and `google-cloud-speech>=2.36` (was `>=2`).

**Upstream sync brought in** (`llm.py`, `stt.py`, `tts.py`, `realtime_api.py`,
`utils.py`, `beta/`, `version.py`, `pyproject.toml`): a genai HTTP client leak fix on
session close, model-turn text no longer leaking into captions when audio output and
output transcription are both on, `turn_started_at` on transcription events, `SILENT`
tool-response scheduling driven by `reply_required`, warnings when
`tool_response_scheduling` is used on Vertex (which ignores it), PII-tagged debug logs,
and a new `beta/gemini_stt.py`.

---

## v1.0.5 — sync to upstream plugin 1.6.7 (livekit-agents 1.6.7)

**Compatibility:** `livekit==1.1.13`, `livekit-agents==1.6.7`.
**Base:** upstream `livekit-plugins-google` 1.6.7 (synced from 1.6.4).

**Upstream sync brought in** (`llm.py`, `stt.py`, `realtime_api.py`, `utils.py`,
`version.py`, `pyproject.toml`): the 1.6.4 → 1.6.7 plugin changes, incl. an `llm.py`
refactor and `stt.py` updates.

**Fork patches added in this tag:**
- **Realtime tool params preserve pre-filled values.** In `realtime/realtime_api.py`,
  `create_tools_config(...)` is now called with `use_parameters_json_schema=True`
  (upstream defaults it to `False` for realtime). This sends the **full raw JSON
  schema** (`parameters_json_schema`) for MCP/raw tools instead of the lossy
  simplified schema, so pre-filled parameters (e.g. `automationId`, `version`) reach
  Gemini and the model produces valid calls.
  - Context: upstream defaults to `False` because early Gemini **Live** models
    rejected `parameters_json_schema` and returned empty args
    ([googleapis/python-genai#1147](https://github.com/googleapis/python-genai/issues/1147)).
    Current Gemini 3.x realtime models accept it. **If you point this at an older Live
    model that errors or omits args on connect, revert this flag to `False`.**
- **Keep `default` in `_GeminiJsonSchema.simplify()`** (`utils.py`). The simplify path
  is still used for plain `@function_tool` tools (and structured-output schemas). It
  previously dropped the JSON-schema `default` key, silently losing defaults on
  non-raw tools; `default` is now preserved (`$schema`, `additionalProperties`, and
  `title` are still stripped, as Gemini rejects them).
- **Docs:** added this `CHANGELOG.md` and expanded `README.md`.

**Carried-forward fork patches** (from earlier tags, still present): realtime
stash-and-replay of tool results across `update_tools`; conditionalized generation
triggers for non-Vertex models.

---

## v1.0.4 — sync to upstream plugin 1.6.4 (livekit-agents 1.6.4)

**Compatibility:** `livekit==1.1.12`, `livekit-agents==1.6.4`.
**Base:** upstream `livekit-plugins-google` 1.6.4 (synced from 1.5.17).

Pure upstream sync (no new fork-specific patch). Diff vs `v1.0.3`:
- `realtime_api.py`: substantial update (~+105 lines) from the 1.6.4 plugin.
- `beta/gemini_tts.py`, `llm.py`, `stt.py`, `utils.py`: upstream refinements.
- `pyproject.toml`: `livekit-agents` pin raised to `>=1.6.4`.

Carried-forward fork patches remain in place.

## v1.0.3 — sync to upstream plugin 1.5.17 (livekit-agents 1.5.17)

**Compatibility:** `livekit==1.1.8`, `livekit-agents==1.5.17`.
**Base:** upstream `livekit-plugins-google` 1.5.17 (synced from 1.5.4).

Pure upstream sync. Diff vs `v1.0.2`:
- **New file `aiplatform_llm.py`** (~+322 lines) — Vertex AI Platform LLM support from
  upstream.
- `llm.py` (~+58), `stt.py`, `realtime_api.py`, `utils.py`, `models.py`: upstream
  updates.
- `pyproject.toml`: `livekit-agents` pin raised to `>=1.5.17`.

Carried-forward fork patches remain in place.

## v1.0.2 — pin to upstream plugin 1.5.4 (livekit-agents 1.5.4)

**Compatibility:** `livekit==1.1.5`, `livekit-agents==1.5.4`.

**Fork patch added in this tag:**
- **Conditionalize generation triggers for non-Vertex models** (`realtime_api.py`).
  Only fire the relevant generation triggers on the Gemini API (non-Vertex) path.

Also raised the `livekit-agents` pin to `>=1.5.4` in `pyproject.toml`.

## v1.0.1 — realtime tool-result durability (livekit-agents ≥ 1.5.0)

**Compatibility:** `livekit-agents>=1.5.0` (livekit SDK version not documented).

**Fork patch added in this tag:**
- **Stash and replay tool result after `update_tools`** (`realtime_api.py`, +34/−10).
  When the realtime session restarts to apply a tool change, the in-flight tool
  result is stashed and replayed to the new session instead of being lost.

## v1.0.0 — initial fork release (livekit-agents ≥ 1.5.0)

**Compatibility:** `livekit-agents>=1.5.0` (livekit SDK version not documented).

First tagged release. Vendors the full `livekit-plugins-google` package under
`livekit/plugins/google/` (`llm.py`, `stt.py`, `tts.py`, `models.py`, `utils.py`,
`tools.py`, `beta/gemini_tts.py`, and the `realtime/` module) with **Gemini realtime
support, including Gemini 3.1 realtime**. Adds `LICENSE` and `NOTICE`.

---

## Which tag should I use?

Match the tag to the **`livekit-agents`** version your project already uses:

- On `livekit-agents==1.6.7` → use **`v1.0.5`**
- On `livekit-agents==1.6.4` → use **`v1.0.4`**
- On `livekit-agents==1.5.17` → use **`v1.0.3`**
- On `livekit-agents==1.5.4` → use **`v1.0.2`**
- On `livekit-agents` 1.5.0–1.5.3 → use **`v1.0.1`** (or `v1.0.0`)

Install a specific tag directly from Git:

```bash
pip install "git+https://github.com/heershah434/livekit-google-plugin.git@v1.0.5"
```

Or pin it in `requirements.txt` / `pyproject.toml`:

```
livekit-plugins-google @ git+https://github.com/heershah434/livekit-google-plugin.git@v1.0.5
```

> Do not mix a fork tag with a mismatched `livekit-agents` version — the plugin
> relies on internal `livekit-agents` APIs and will break across incompatible
> versions.
