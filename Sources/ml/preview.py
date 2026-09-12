"""Disposable live draft state sharing the existing cached model's weights.

Only preview module wrappers and attention state are separate. The final model
keeps its original attention objects and decoding settings. We own the stream
without its context-manager entry/exit so it cannot swap those attention objects
or clear the shared MLX allocator cache when a recording ends.
"""

from __future__ import annotations

import base64
import copy
from typing import Any

from .loader import load_parakeet_model


class PreviewSessions:
    def __init__(self, loader=None):
        self.loader = loader or load_parakeet_model
        self.session_id = None
        self.stream = None
        self.sequence = 0

    def start(self, session_id: str, repo: str) -> dict[str, Any]:
        if not isinstance(session_id, str) or not session_id:
            raise ValueError("session_id is required")
        self.clear()
        model = self.loader(repo)
        # Shallow-copy only wrappers that set_attention_model mutates. All trained
        # MLX arrays remain shared; the cached final model is never reconfigured.
        preview_model = copy.copy(model)
        preview_model.encoder = copy.copy(model.encoder)
        preview_model.encoder.layers = [copy.copy(layer) for layer in model.encoder.layers]
        preview_model.encoder.set_attention_model("rel_pos_local_attn", (128, 8))
        self.stream = preview_model.transcribe_stream(
            context_size=(128, 8), depth=1, keep_original_attention=True
        )
        self.session_id = session_id
        return {"success": True}

    def append(self, session_id: str, sequence: int, audio_b64: str) -> dict[str, Any]:
        if session_id != self.session_id or self.stream is None:
            return {"active": False, "stable": "", "draft": ""}
        if sequence != self.sequence:
            raise ValueError("Preview audio arrived out of order")
        raw = base64.b64decode(audio_b64, validate=True)
        if not raw or len(raw) % 4 or len(raw) > 16000 * 4 * 8:
            raise ValueError("Preview requires up to eight seconds of mono 16 kHz Float32 PCM")
        import numpy as np
        import mlx.core as mx

        samples = np.frombuffer(raw, dtype="<f4")
        if not np.isfinite(samples).all():
            raise ValueError("Preview audio contains non-finite samples")
        self.stream.add_audio(mx.array(samples))
        self.sequence += 1
        return {
            "active": True,
            "stable": "".join(token.text for token in self.stream.finalized_tokens),
            "draft": "".join(token.text for token in self.stream.draft_tokens),
        }

    def clear(self, session_id: str | None = None) -> dict[str, Any]:
        if session_id is None or session_id == self.session_id:
            self.stream = None
            self.session_id = None
            self.sequence = 0
        return {"success": True}


sessions = PreviewSessions()
