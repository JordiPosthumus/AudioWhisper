"""Download boundaries: cached models stay untouched; setup alone may fetch."""
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Sources"))
from ml.setup import prepare_model, verify_model
from huggingface_hub.errors import LocalEntryNotFoundError


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        for name in ("config.json", "model.safetensors"):
            (self.root / name).write_bytes(b"fixture")

    def tearDown(self):
        self.directory.cleanup()

    def test_existing_cache_never_uses_network(self):
        with patch("huggingface_hub.hf_hub_download", side_effect=lambda repo, name, **kw: str(self.root / name)) as local, \
             patch("huggingface_hub.snapshot_download") as network:
            self.assertFalse(prepare_model()["downloaded"])
            network.assert_not_called()
            self.assertTrue(all(call.kwargs == {"local_files_only": True} for call in local.call_args_list))

    def test_missing_cache_downloads_only_the_required_model_files(self):
        with patch("huggingface_hub.hf_hub_download", side_effect=LocalEntryNotFoundError("missing")), \
             patch("huggingface_hub.snapshot_download", return_value=str(self.root)) as network:
            self.assertTrue(prepare_model()["downloaded"])
            network.assert_called_once_with("mlx-community/parakeet-tdt-0.6b-v2", allow_patterns=["config.json", "model.safetensors"])

    def test_incomplete_download_does_not_claim_success(self):
        (self.root / "model.safetensors").unlink()
        with patch("huggingface_hub.hf_hub_download", side_effect=LocalEntryNotFoundError("missing")), \
             patch("huggingface_hub.snapshot_download", return_value=str(self.root)):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                prepare_model()

    def test_network_failure_is_reported_for_retry(self):
        with patch("huggingface_hub.hf_hub_download", side_effect=LocalEntryNotFoundError("missing")), \
             patch("huggingface_hub.snapshot_download", side_effect=ConnectionError("offline")):
            with self.assertRaises(ConnectionError):
                prepare_model()

    def test_verification_uses_normal_decoder_and_removes_only_its_fixture(self):
        paths = []
        def transcribe(repo, path):
            self.assertEqual(repo, "mlx-community/parakeet-tdt-0.6b-v2")
            self.assertEqual(Path(path).read_bytes(), bytes(16_000 * 4))
            paths.append(Path(path))
            return {"success": True, "text": ""}
        with patch("ml.parakeet.transcribe", side_effect=transcribe):
            self.assertTrue(verify_model()["success"])
        self.assertFalse(paths[0].exists())


if __name__ == "__main__":
    unittest.main()
