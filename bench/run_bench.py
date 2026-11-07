#!/usr/bin/env python3
"""Measure moonvsim throughput and compare it against Icarus Verilog.

The benchmark design (`examples/bench.v`) runs a 16-bit LFSR, a 32-bit
accumulator and a small combinational datapath for 200,000 simulated
nanoseconds, that is 20,000 rising edges of a 100 MHz clock. Both simulators
execute the exact same source and are required to print the same final state,
so the timing numbers are directly comparable.

Usage:
    python bench/run_bench.py [--moonvsim PATH] [--iverilog PATH] [--repeat N]

The script prints a table and writes `bench/RESULTS.md`.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "examples" / "bench.v"
TOP = "bench_tb"
MAX_TIME = 200_000
CYCLES = 20_000  # 10 ns per clock period

EXE = ".exe" if os.name == "nt" else ""


def default_moonvsim() -> Path:
    # `cmd.exe` is what the native backend emits, on Linux as well.
    for profile in ("release", "debug"):
        for name in ("cmd.exe", "cmd"):
            p = ROOT / "_build" / "native" / profile / "build" / "src" / "cmd" / name
            if p.exists():
                return p
    return ROOT / "_build" / "native" / "release" / "build" / "src" / "cmd" / f"cmd{EXE}"


def default_iverilog() -> str:
    local = ROOT.parent / "tools" / "iverilog" / "mingw64" / "bin" / "iverilog.exe"
    if local.exists():
        return str(local)
    found = shutil.which("iverilog")
    if found:
        return found
    sys.exit("error: iverilog not found; pass --iverilog or run CI")


def run(cmd: list[str], cwd: Path) -> tuple[float, str]:
    start = time.perf_counter()
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, timeout=600)
    elapsed = time.perf_counter() - start
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(f"error: {' '.join(cmd)} failed with {proc.returncode}")
    return elapsed, proc.stdout


def final_state(text: str) -> str:
    for line in reversed(text.splitlines()):
        if line.startswith("bench done"):
            return line.strip()
    return "<missing>"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--moonvsim", default=str(default_moonvsim()))
    ap.add_argument("--iverilog", default=default_iverilog())
    ap.add_argument("--repeat", type=int, default=3)
    args = ap.parse_args()

    moonvsim = Path(args.moonvsim)
    if not moonvsim.exists():
        sys.exit(f"error: {moonvsim} does not exist; run `moon build src/cmd --target native --release`")

    iv = Path(args.iverilog)
    vvp = iv.with_name("vvp" + iv.suffix)
    vvp_file = ROOT / "bench" / f"{TOP}.vvp"
    run([str(iv), "-g2005", "-o", str(vvp_file), "-s", TOP, str(DESIGN)], ROOT)

    results = []
    for label, cmd in (
        ("moonvsim", [str(moonvsim), "run", str(DESIGN), "--top", TOP, "--max-time", str(MAX_TIME)]),
        ("iverilog", [str(vvp), str(vvp_file)]),
    ):
        samples = []
        state = ""
        for _ in range(args.repeat):
            elapsed, out = run(cmd, ROOT)
            samples.append(elapsed)
            state = final_state(out)
        results.append((label, min(samples), state))

    states = {state for _, _, state in results}
    rows = []
    for label, seconds, state in results:
        rate = CYCLES / seconds
        rows.append((label, seconds, rate, state))

    lines = [
        "# Simulator throughput",
        "",
        f"Design: `examples/bench.v` (`{TOP}`), {MAX_TIME:,} simulated ns = {CYCLES:,} clock cycles.",
        f"Best of {args.repeat} runs, wall clock, process start included.",
        "",
        "| simulator | wall time | cycles / s | final state |",
        "| --- | --- | --- | --- |",
    ]
    for label, seconds, rate, state in rows:
        lines.append(f"| {label} | {seconds * 1000:.0f} ms | {rate:,.0f} | `{state}` |")
    agree = len(states) == 1 and "<missing>" not in states
    lines += ["", f"Both simulators report {'the same' if agree else 'different'} final state.", ""]
    if not agree:
        lines.append("WARNING: the two simulators disagree; treat the timing table as meaningless.")

    report = "\n".join(lines) + "\n"
    (ROOT / "bench" / "RESULTS.md").write_text(report, encoding="utf-8", newline="\n")
    print(report)
    return 0 if agree else 1


if __name__ == "__main__":
    raise SystemExit(main())
