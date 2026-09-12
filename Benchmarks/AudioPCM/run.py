#!/usr/bin/env python3
"""Reproduce PCM conversion measurements against the upstream implementation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--baseline", default="71fed36")
parser.add_argument("--runs", type=int, default=5)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
if args.runs < 1:
    parser.error("--runs must be positive")
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="audiowhisper-pcm-") as temp:
    work = Path(temp)
    original = work / "OriginalAudioProcessor.swift"
    original.write_bytes(subprocess.check_output([
        "git", "show", f"{args.baseline}:Sources/Services/Audio/AudioProcessor.swift"
    ], cwd=root))
    main = root / "Benchmarks/AudioPCM/main.swift"
    subprocess.run(["xcrun", "swiftc", "-O", str(original), str(main), "-o", str(work / "original")], check=True)
    subprocess.run(["xcrun", "swiftc", "-O", "-DSTREAMING_PCM", str(root / "Sources/Services/Audio/AudioProcessor.swift"), str(main), "-o", str(work / "streaming")], check=True)
    subprocess.run([str(work / "streaming"), "--generate", str(work / "input.caf")], check=True)
    measurements = []
    for iteration in range(args.runs):
        order = ["original", "streaming"] if iteration % 2 == 0 else ["streaming", "original"]
        for mode in order:
            result = subprocess.run([
                "/usr/bin/time", "-l", str(work / mode), str(work / "input.caf"), str(work / f"{mode}.raw")
            ], capture_output=True, text=True, check=True)
            measurements.append({
                "iteration": iteration + 1,
                "mode": mode,
                "seconds": float(re.search(r"Conversion: ([0-9.]+)", result.stdout)[1]),
                "peak_rss_bytes": int(re.search(r"(\d+)\s+maximum resident set size", result.stderr)[1]),
            })
    hashes = {}
    for mode in ["original", "streaming"]:
        with (work / f"{mode}.raw").open("rb") as audio:
            digest = hashlib.sha256()
            for block in iter(lambda: audio.read(1024 * 1024), b""):
                digest.update(block)
        hashes[mode] = digest.hexdigest()
    if hashes["original"] != hashes["streaming"]:
        raise SystemExit("PCM outputs differ")
    report = {"baseline": args.baseline, "duration_minutes": 30, "output_sha256": hashes, "measurements": measurements}
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    print(rendered)
    for mode in ["original", "streaming"]:
        records = [row for row in measurements if row["mode"] == mode]
        print(f"{mode}: median {statistics.median(r['seconds'] for r in records):.6f} s, "
              f"peak RSS {statistics.median(r['peak_rss_bytes'] for r in records):,.0f} bytes")
