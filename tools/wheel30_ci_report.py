#!/usr/bin/env python3
"""Validate official Wheel-30 output and record public CI hardware provenance."""
import argparse
from datetime import datetime, timezone
import json, math, os, re
from pathlib import Path
from ci_report import cpu_snapshot

EXPECTED_VERSION = "odin version dev-2026-10-nightly:84bc3fc"
LABELS = {"odin_wheel30": ("single", 1)}
TAG = "algorithm=wheel,faithful=yes,bits=1"

def parse(output):
    rows={}
    for line in output.splitlines():
        parts=line.strip().split(";")
        if len(parts)!=5 or parts[0] not in LABELS:
            continue
        label,p,s,t,tags=parts
        if label in rows: raise ValueError("Duplicate Wheel-30 measurement")
        try:
            passes,secs,workers=int(p),float(s),int(t)
        except ValueError as e:
            raise ValueError("Invalid Wheel-30 measurement") from e
        required=LABELS[label][1]
        if passes<=0 or not math.isfinite(secs) or not 5<=secs<60 or workers<1 or tags!=TAG or (required is not None and workers!=required):
            raise ValueError("Invalid Wheel-30 lane: "+line)
        rows[label]={"label":label,"mode":LABELS[label][0],"bits":1,"workers":workers,"passes":passes,"seconds":secs,"passes_per_second":passes/secs}
    if set(rows)!=set(LABELS): raise ValueError("Missing Wheel-30 output lanes")
    return [rows[k] for k in LABELS]

def build_record(output,version,sha,run_id,host):
    if version.strip()!=EXPECTED_VERSION: raise ValueError("Unexpected compiler: "+version.strip())
    if not re.fullmatch(r"[0-9a-f]{40}",sha) or not str(run_id).isdecimal(): raise ValueError("Invalid GitHub run provenance")
    lanes=parse(output)
    logical,affinity=host.get("logical_cpus"),host.get("affinity_cpus")
    if not isinstance(logical,int) or logical<1 or not isinstance(affinity,int) or affinity<1:
        raise ValueError("No runner CPU count/affinity")
    if any(v["workers"]>logical for v in lanes): raise ValueError("Workers exceed logical CPUs")
    return {
        "schema_version":1,"status":"passed","source":"github-actions","track":"wheel-30",
        "classification":"CI screening, not official PrimeView","algorithm":"wheel",
        "faithfulness":"proposed; subject to upstream review",
        "run_id":str(run_id),"commit":sha,"measured_at_utc":datetime.now(timezone.utc).isoformat(),
        "limit":1000000,"known_prime_count":78498,
        "compiler":version.strip().removeprefix("odin version "),
        "compiler_archive_sha256":"c3c8b095621fd0c75f7f73e3a0829f1b4d45324225f20ba11ed8dc4da310a8ab",
        "build_flags":"-o:speed -microarch:native -no-bounds-check -disable-assert",
        "source_path":"wheel30/main.odin","host":host,"lanes":lanes
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=Path)
    ap.add_argument("--version-file",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    record=build_record(args.input.read_text(),args.version_file.read_text(),os.environ["GITHUB_SHA"],os.environ["GITHUB_RUN_ID"],cpu_snapshot())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(record,indent=2)+"\n")
    print("WHEEL_CI_JSON="+json.dumps(record,separators=(",",":")))
    print("Wheel-30 CI PASS:",record["host"]["cpu_model"])

if __name__=="__main__":
    main()
