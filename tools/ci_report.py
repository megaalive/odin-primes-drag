#!/usr/bin/env python3
"""Create a publishable CI measurement record. Python standard library only."""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess

LABELS = {
    "odin_bit_moe": (1, 1),
    "odin_bit_threaded_moe": (1, None),
    "odin_byte_moe": (8, 1),
    "odin_byte_threaded_moe": (8, None),
}
COMPILER = "b277d66e008e15d640208f3e11515b047f78be48"


def parse(output):
    rows = {}
    for line in output.splitlines():
        parts = line.strip().split(";")
        if len(parts) != 5 or parts[0] not in LABELS:
            continue
        label, count, duration, workers, tags = parts
        if label in rows:
            raise ValueError("Duplicate measurement " + label)
        passes, seconds, n = int(count), float(duration), int(workers)
        bits, required_threads = LABELS[label]
        if (passes <= 0 or not 5 <= seconds < 60 or not math.isfinite(seconds)
                or n < 1 or (required_threads is not None and n != required_threads)
                or set(tags.split(",")) != {"algorithm=base", "faithful=yes", "bits=" + str(bits)}):
            raise ValueError("Invalid measurement " + line)
        rows[label] = {"label": label, "bits": bits, "workers": n,
                       "passes": passes, "seconds": seconds,
                       "passes_per_second": passes / seconds}
    if set(rows) != set(LABELS):
        raise ValueError("Missing lanes: " + str(set(LABELS) - set(rows)))
    if rows["odin_bit_threaded_moe"]["workers"] != rows["odin_byte_threaded_moe"]["workers"]:
        raise ValueError("Thread counts differ between parallel lanes")
    return [rows[label] for label in LABELS]


def cpu_snapshot():
    text = Path("/proc/cpuinfo").read_text(errors="replace") if Path("/proc/cpuinfo").exists() else ""
    first = text.split("\n\n", 1)[0]
    def field(key):
        return next((line.split(":", 1)[1].strip()
                     for line in first.splitlines()
                     if ":" in line and line.split(":", 1)[0].strip() == key), None)
    affinity = len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None
    virt = None
    try:
        v = subprocess.run(["systemd-detect-virt"], capture_output=True,
                           text=True, timeout=4, check=False)
        virt = v.stdout.strip() if v.returncode == 0 else "none"
    except (OSError, subprocess.TimeoutExpired):
        virt = None
    return {"cpu_model": field("model name") or "Not reported",
            "vendor": field("vendor_id"),
            "logical_cpus": os.cpu_count(),
            "affinity_cpus": affinity,
            "machine": platform.machine(),
            "runner_image": os.environ.get("ImageOS", "ubuntu-24.04"),
            "kernel": platform.release(),
            "virtualization": virt}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    sha = os.environ["GITHUB_SHA"]
    run_id = os.environ["GITHUB_RUN_ID"]
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or not run_id.isdecimal():
        raise ValueError("Missing verified GitHub run provenance")
    lanes = parse(args.input.read_text())
    host = cpu_snapshot()
    if host["logical_cpus"] is None or host["affinity_cpus"] is None:
        raise ValueError("Missing runner CPU count/affinity")
    if any(row["workers"] > host["logical_cpus"] for row in lanes):
        raise ValueError("Reported thread count greater than available CPUs")
    record = {"schema_version": 1, "status": "passed", "source": "github-actions",
              "classification": "CI screening, not official PrimeView",
              "run_id": run_id, "commit": sha,
              "measured_at_utc": datetime.now(timezone.utc).isoformat(),
              "limit": 1000000, "known_prime_count": 78498,
              "compiler_commit": COMPILER, "host": host, "lanes": lanes}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + "\n")
    print("CI_RESULT_JSON=" + json.dumps(record, separators=(",", ":")))
    print("Verified 4 benchmark lanes; CPU:", host["cpu_model"])
    print("Runner logical CPUs:", host["logical_cpus"], "affinity:", host["affinity_cpus"])


if __name__ == "__main__":
    main()
