"""Live drafts from a rolling audio window using the unchanged cached model.

Normal full-attention decoding avoids the severe accuracy loss of the installed
library's streaming approximation. Only eight seconds of preview PCM are kept;
the independent AAC recording still supplies the complete final transcription.
"""

from __future__ import annotations

import base64
from typing import Any

from .loader import load_parakeet_model
from .parakeet import extract_parakeet_text


class PreviewSessions:
    def __init__(self, loader=None):
        self.loader = loader or load_parakeet_model
        self.session_id = None
        self.model = None
        self.audio = bytearray()
        self.sequence = 0

    def start(self, session_id: str, repo: str) -> dict[str, Any]:
        if not isinstance(session_id, str) or not session_id:
            raise ValueError("session_id is required")
        self.clear()
        self.model = self.loader(repo)
        self.session_id = session_id
        return {"success": True}

    def append(self, session_id: str, sequence: int, audio_b64: str) -> dict[str, Any]:
        if session_id != self.session_id or self.model is None:
            return {"active": False, "stable": "", "draft": ""}
        if sequence != self.sequence:
            raise ValueError("Preview audio arrived out of order")
        raw = base64.b64decode(audio_b64, validate=True)
        if not raw or len(raw) % 4 or len(raw) > 16000 * 4 * 8:
            raise ValueError("Preview requires up to eight seconds of mono 16 kHz Float32 PCM")
        import numpy as np
        import mlx.core as mx
        from parakeet_mlx.audio import get_logmel

        samples = np.frombuffer(raw, dtype="<f4")
        if not np.isfinite(samples).all():
            raise ValueError("Preview audio contains non-finite samples")
        self.audio.extend(raw)
        del self.audio[:max(0, len(self.audio) - 16000 * 4 * 8)]
        # Re-decode the recent window so a bad partial word cannot corrupt later
        # updates. No attention swaps, stream decoder state, or allocator clears.
        window = np.frombuffer(bytes(self.audio), dtype="<f4")
        mel = get_logmel(mx.array(window), self.model.preprocessor_config)
        text = extract_parakeet_text(self.model.generate(mel))
        self.sequence += 1
        return {
            "active": True,
            "stable": "",
            "draft": text,
        }

    def clear(self, session_id: str | None = None) -> dict[str, Any]:
        if session_id is None or session_id == self.session_id:
            self.model = None
            self.audio.clear()
            self.session_id = None
            self.sequence = 0
        return {"success": True}


sessions = PreviewSessions()
