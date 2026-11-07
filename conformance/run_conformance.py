"""Conformance runner for moonvsim.

Runs every self-checking testbench under conformance/ twice:

  1. with the moonvsim CLI (the simulator under test), and
  2. with Icarus Verilog (the reference simulator), when it is installed.

Both runs are self-checking: each testbench prints ``PASS <name>`` or
``FAIL <name>`` lines. The runner compares the two sets of check results and
fails when they disagree, so a divergence is reported as a conformance bug
instead of being hidden by a single golden file.

Usage:
    python conformance/run_conformance.py [--moonvsim PATH] [--iverilog PATH]
                                          [--timeout SECONDS] [--json PATH]
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_MOONVSIM = os.path.join(
    ROOT, "_build", "native", "debug", "build", "src", "cmd", "cmd.exe"
)
DEFAULT_IVERILOG = r"E:\ds\tools\iverilog\mingw64\bin\iverilog.exe"

CHECK_RE = re.compile(r"^(PASS|FAIL)\s+(\S+)(.*)$")


def run(cmd, timeout, cwd=None):
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd
        )
        return proc.returncode, proc.stdout + proc.stderr
    except FileNotFoundError:
        return 127, "not found"
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def parse_checks(text):
    checks = {}
    for line in text.splitlines():
        m = CHECK_RE.match(line.strip())
        if m:
            checks[m.group(2)] = (m.group(1) == "PASS", m.group(3).strip())
    return checks


def run_moonvsim(exe, design, top, timeout, workdir):
    return run([exe, "run", design, "--top", top, "--max-time", "5000"], timeout, workdir)


def run_iverilog(exe, design, top, timeout, workdir):
    vvp = os.path.join(workdir, top + ".vvp")
    code, out = run([exe, "-g2005", "-o", vvp, "-s", top, design], timeout, workdir)
    if code != 0:
        return code, out
    vvp_exe = os.path.join(os.path.dirname(exe), "vvp.exe")
    return run([vvp_exe, vvp], timeout, workdir)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--moonvsim", default=DEFAULT_MOONVSIM)
    ap.add_argument("--iverilog", default=DEFAULT_IVERILOG)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--json", default=os.path.join(HERE, "report.json"))
    args = ap.parse_args()

    designs = sorted(
        os.path.join(HERE, f) for f in os.listdir(HERE) if f.endswith(".v")
    )
    have_iverilog = os.path.isfile(args.iverilog)
    if not os.path.isfile(args.moonvsim):
        print("moonvsim binary not found:", args.moonvsim)
        print("build it with: moon build src/cmd --target native")
        return 2

    report = {
        "moonvsim": args.moonvsim,
        "iverilog": args.iverilog if have_iverilog else None,
        "designs": [],
    }
    total = 0
    passed = 0
    diverged = 0

    print("design                 checks  moonvsim  iverilog  verdict")
    print("-" * 68)
    for path in designs:
        top = os.path.splitext(os.path.basename(path))[0]
        code, ours_text = run_moonvsim(
            args.moonvsim, path, top, args.timeout, ROOT
        )
        ours = parse_checks(ours_text)
        theirs = None
        if have_iverilog:
            code2, their_text = run_iverilog(args.iverilog, path, top, args.timeout, HERE)
            theirs = parse_checks(their_text)

        ok = sum(1 for v in ours.values() if v[0])
        total += len(ours)
        passed += ok

        verdict = "ok"
        if code != 0 and not ours:
            verdict = "no-output"
        if theirs is not None:
            keys = set(ours) | set(theirs)
            mismatched = [
                k
                for k in sorted(keys)
                if k not in ours or k not in theirs or ours[k][0] != theirs[k][0]
            ]
            if mismatched:
                diverged += 1
                verdict = "DIVERGES(" + ",".join(mismatched) + ")"
        elif any(not v[0] for v in ours.values()):
            verdict = "failing"

        print(
            "%-22s %6d  %8s  %8s  %s"
            % (
                os.path.basename(path),
                len(ours),
                "%d/%d" % (ok, len(ours)),
                ("%d" % len(theirs)) if theirs is not None else "-",
                verdict,
            )
        )
        report["designs"].append(
            {
                "design": os.path.basename(path),
                "top": top,
                "checks": {k: {"pass": v[0], "detail": v[1]} for k, v in ours.items()},
                "reference": (
                    {k: {"pass": v[0], "detail": v[1]} for k, v in theirs.items()}
                    if theirs is not None
                    else None
                ),
                "verdict": verdict,
            }
        )

    report["summary"] = {
        "designs": len(designs),
        "checks": total,
        "passed": passed,
        "diverged": diverged,
        "reference": "iverilog" if have_iverilog else "none",
    }
    with open(args.json, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=2)
        f.write("\n")

    print("-" * 68)
    print(
        "%d designs, %d checks, %d passed, %d diverged, reference=%s"
        % (len(designs), total, passed, diverged, report["summary"]["reference"])
    )
    return 0 if diverged == 0 and passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
