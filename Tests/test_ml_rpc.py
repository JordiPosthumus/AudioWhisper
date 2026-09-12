"""Protocol regressions without loading or downloading any models."""
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Sources"))
from ml import rpc


class RPCRegressionTests(unittest.TestCase):
    def test_invalid_requests_do_not_kill_daemon(self):
        invalid = [None, [], 42, "text", {"id": 5, "method": "ping", "params": []}]
        lines = [json.dumps(value) for value in invalid]
        lines += ['{bad', json.dumps({"id": 7, "method": "ping"})]
        out = io.StringIO()
        with patch.object(sys, "stdin", io.StringIO("\n".join(lines))), patch.object(sys, "stdout", out):
            self.assertEqual(rpc.main(), 0)
        responses = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(len(responses), 7)
        self.assertTrue(all("error" in response for response in responses[:-1]))
        self.assertEqual(responses[-1]["result"], {"pong": True})

    def test_model_logging_does_not_corrupt_responses(self):
        def noisy_transcribe(repo, path):
            print("Loading model...")
            return {"success": True, "text": "hello"}

        out, err = io.StringIO(), io.StringIO()
        with patch.object(rpc, "transcribe", noisy_transcribe), patch.object(sys, "stdout", out), patch.object(sys, "stderr", err):
            rpc._handle_request({"id": 1, "method": "transcribe", "params": {"pcm_path": "test.raw"}})
        self.assertEqual(json.loads(out.getvalue())["result"]["text"], "hello")
        self.assertIn("Loading model", err.getvalue())

    def test_stdout_is_restored_after_model_error(self):
        out = io.StringIO()
        with patch.object(rpc, "load_parakeet_model", side_effect=RuntimeError("load failed")), patch.object(sys, "stdout", out):
            rpc._handle_request({"id": 3, "method": "warmup", "params": {"type": "parakeet", "repo": "test"}})
            rpc._handle_request({"id": 4, "method": "ping"})
        responses = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(responses[0]["error"]["message"], "load failed")
        self.assertEqual(responses[1]["result"], {"pong": True})


if __name__ == "__main__":
    unittest.main()
