"""Explicit first-run download. Normal inference remains strictly offline."""

from pathlib import Path

from .parakeet import DEFAULT_PARAKEET_REPO


def prepare_model():
    from huggingface_hub import hf_hub_download, snapshot_download
    from huggingface_hub.errors import LocalEntryNotFoundError

    files = ("config.json", "model.safetensors")
    # An established installation never makes a network request or updates its
    # revision. Interrupted downloads are resumed by the Hub's normal cache logic.
    try:
        cached = [Path(hf_hub_download(DEFAULT_PARAKEET_REPO, name, local_files_only=True)) for name in files]
        if all(path.is_file() and path.stat().st_size > 0 for path in cached):
            return {"success": True, "downloaded": False}
    except LocalEntryNotFoundError:
        pass

    snapshot = Path(snapshot_download(DEFAULT_PARAKEET_REPO, allow_patterns=list(files)))
    if not all((snapshot / name).is_file() and (snapshot / name).stat().st_size > 0 for name in files):
        raise RuntimeError("The speech-model download is incomplete. Please try setup again.")
    return {"success": True, "downloaded": True}


def verify_model():
    import tempfile
    from .parakeet import transcribe

    # Exercise the normal decoder once on synthetic silence, without accessing
    # the microphone, clipboard or history. This also warms its first-use work.
    with tempfile.NamedTemporaryFile(suffix=".raw") as audio:
        audio.write(bytes(16_000 * 4))
        audio.flush()
        result = transcribe(DEFAULT_PARAKEET_REPO, audio.name)
    if not result.get("success"):
        raise RuntimeError("The local speech model did not pass its setup check.")
    return {"success": True}
