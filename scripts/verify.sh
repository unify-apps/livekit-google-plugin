#!/usr/bin/env bash
# Sanity checks for the vendored+patched tree. Run after syncing to a new upstream.
#
#   scripts/verify.sh              # static checks only
#   scripts/verify.sh /path/to/venv/bin/python   # + runtime checks against an install
#
# The runtime checks need a python that already has this package AND the matching
# livekit-agents installed:
#   uv venv .venv && .venv/bin/python -m pip install "livekit-agents==1.9.0" .
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${1:-}"

echo "== syntax =="
python3 -m compileall -q livekit >/dev/null && echo "  compileall OK"

echo "== fork patches still present =="
check() { grep -q "$2" "$1" && echo "  OK   $3" || { echo "  MISS $3"; exit 1; }; }
check livekit/plugins/google/utils.py                'intentionally keep "default"'        'keep JSON-schema "default" in simplify()'
check livekit/plugins/google/realtime/realtime_api.py 'use_parameters_json_schema=True'     'send parameters_json_schema on realtime'
check livekit/plugins/google/realtime/realtime_api.py '_generation_completed'               'drop stale model_turn after turn end'
check livekit/plugins/google/realtime/realtime_api.py 'emit after the backoff'              'emit recoverable errors after backoff'
check livekit/plugins/google/utils.py                'def with_gemini_api_version'          'default the Gemini API version to v1beta'
for f in llm.py realtime/realtime_api.py beta/gemini_stt.py beta/gemini_tts.py beta/gemini_translation.py; do
  check "livekit/plugins/google/$f" 'with_gemini_api_version(' "v1beta default applied in $f"
done

if [ -z "$PY" ]; then
  echo "== runtime checks skipped (pass a python from an env with this package installed) =="
  exit 0
fi

# Run from a scratch dir: this repo's livekit/__init__.py would otherwise shadow the
# installed `livekit` namespace and hide livekit.rtc.
echo "== runtime (against $PY) =="
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && "$PY" - <<'PYCODE'
import inspect
import livekit.plugins.google as g, livekit.agents as A
from livekit import rtc  # noqa: F401
from livekit.plugins.google.realtime.realtime_api import RealtimeModel
from livekit.agents.llm.realtime import RealtimeModel as Base

print(f"  import OK   plugin {g.__version__} / livekit-agents {A.__version__}")

# The drift that broke v1.0.5: agents 1.8.x calls session(turn_detection_disabled=...)
# unconditionally, and a stale vendored tree still declares session(self).
ours, base = inspect.signature(RealtimeModel.session), inspect.signature(Base.session)
missing = set(base.parameters) - set(ours.parameters)
assert not missing, f"session() is missing {missing}: ours={ours} base={base}"
print(f"  session() matches base class {ours}")

from livekit.plugins.google.utils import _GeminiJsonSchema
out = _GeminiJsonSchema(
    {"type": "object", "properties": {"automationId": {"type": "string", "default": "x", "title": "t"}}}
).simplify()
prop = out["properties"]["automationId"]
assert "default" in prop and "title" not in prop, prop
print(f"  simplify() keeps 'default', strips 'title': {prop}")
PYCODE
)
echo "== all checks passed =="
