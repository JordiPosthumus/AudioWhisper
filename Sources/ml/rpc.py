"""JSON-RPC stdin/stdout server for ML tasks."""

from __future__ import annotations

import json
import sys
from contextlib import redirect_stdout
from typing import Any, Dict

from .loader import load_parakeet_model
from .parakeet import DEFAULT_PARAKEET_REPO, transcribe
from .preview import sessions


def _respond(payload: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def _execute(method: str, params: Dict[str, Any]) -> Dict[str, Any]:
    if method == "ping":
        return {"pong": True}
    if method == "transcribe":
        repo = params.get("repo") or DEFAULT_PARAKEET_REPO
        pcm_path = params.get("pcm_path")
        if not pcm_path:
            raise ValueError("pcm_path is required for transcribe")
        # The final pass always owns the model; release only provisional state.
        sessions.clear()
        return transcribe(repo, pcm_path)
    if method == "preview_start":
        return sessions.start(params.get("session_id"), params.get("repo") or DEFAULT_PARAKEET_REPO)
    if method == "preview_audio":
        return sessions.append(params.get("session_id"), params.get("sequence"), params.get("audio_b64"))
    if method == "preview_end":
        session_id = params.get("session_id")
        if not session_id:
            raise ValueError("session_id is required")
        return sessions.clear(session_id)
    if method == "warmup":
        warm_type = params.get("type")
        repo = params.get("repo")
        if not warm_type or not repo:
            raise ValueError("warmup requires 'type' and 'repo'")
        if warm_type == "parakeet":
            load_parakeet_model(repo)
        else:
            raise ValueError(f"Unknown warmup type: {warm_type}")
        return {"success": True}
    raise ValueError(f"Unknown method: {method}")


def _handle_request(request: Any) -> None:
    req_id = request.get("id") if isinstance(request, dict) else None
    try:
        if not isinstance(request, dict):
            raise ValueError("Request must be an object")
        params = request.get("params")
        if params is None:
            params = {}
        if not isinstance(params, dict):
            raise ValueError("params must be an object")
        # Model libraries may print progress; stdout is reserved for RPC frames.
        with redirect_stdout(sys.stderr):
            result = _execute(request.get("method"), params)
        _respond({"jsonrpc": "2.0", "id": req_id, "result": result})
    except Exception as exc:
        _respond({"jsonrpc": "2.0", "id": req_id, "error": {"message": str(exc)}})


def main() -> int:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            _respond({"jsonrpc": "2.0", "id": None, "error": {"message": f"Invalid JSON: {exc}"}})
            continue
        _handle_request(request)
    return 0
