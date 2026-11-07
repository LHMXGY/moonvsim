# moonvsim architecture

## Goal

Simulate synthesizable Verilog-2001 designs deterministically, in MoonBit, with
four-state semantics, and prove conformance against Icarus Verilog.

## Layers

```
        .v source
            |
        [lexer]  tokens
            |
        [parser] AST
            |
     [elaborate] hierarchy flattening, parameters, port binding, widths
            |
          [sim]   evaluator, scheduler, statement execution
           /   \
       [vcd]   [cmd]
                  |
              [web] viewer
```

`src/ast` and `src/value` are shared leaf packages; everything else depends on
them and never the other way round.

## Four-state values

`Bits` keeps three bit planes plus a width and a signedness flag:

| field | meaning |
| --- | --- |
| `val` | bits known to be 1 |
| `unk` | bits whose value is unknown (0, 1 or z) |
| `zed` | subset of `unk` that is high impedance |
| `width` | 1..64 |
| `signed` | decimal interpretation and sign extension |

Every operator implements the IEEE 1364 four-state tables, and unknown
propagation is per-bit rather than all-or-nothing: `4'b1x01 & 4'b1010` is
`4'b10x0`, `4'bx1x1 | 4'b1010` is `4'b1x1x`. Comparison follows 5.1.4: a
comparison is signed only when **both** operands are signed, and `==` reports
`x` when the difference is confined to unknown bits, while `===` never reports
`x`.

## Elaboration

The hierarchy is flattened into one net table whose names are dotted paths
(`dut.sub.count`). Parameters are evaluated top-down in each scope before any
width is computed, so `[W-1:0]` and `output [W:0]` work for both header
parameters and per-instance `#(.W(8))` overrides. Ports are bound by inserting
continuous assignments in the parent scope; declaration initialisers become
continuous assignments for nets and a synthetic `initial` process for
variables, which is what IEEE 1364-2005 §6.2.2 specifies.

## Event scheduling

The scheduler is stratified per time step:

1. snapshot current values (used later for edge detection),
2. run every ready process until it waits, executing blocking assignments
   immediately and queueing non-blocking ones,
3. commit the non-blocking queue,
4. settle: re-evaluate continuous assignments and combinational processes
   until the `dirty` flag stays clear, with a 1000-round delta-cycle cap,
5. detect edges against the snapshot and wake waiters,
6. if anything woke, repeat from 2 within the same time step; otherwise advance
   to the earliest pending `#delay`, clamped by `--max-time`.

Processes are lowered once, at elaboration time, into a small op list
(`Run`, `WaitDelay`, `WaitEdges`, `Jump`, `Finish`), so the interpreter loop has
no AST dispatch overhead for straight-line code and `always #5 clk = ~clk`
becomes `Run / WaitDelay / Jump`.

## Determinism

Processes are executed in declaration order and nets are stored in a stable
id order, so two runs of the same design produce byte-identical output. That is
what makes the differential oracle meaningful: any divergence is a semantics
bug, not scheduling noise.

## Conformance oracle

`conformance/run_conformance.py` builds the same self-checking testbench with
both Icarus Verilog and `moonvsim`, runs both, and compares the `PASS`/`FAIL`
check names and results. A divergence fails the run; the report is written to
`conformance/REPORT.md` and `conformance/report.json`. Current state: 40
designs, 113 checks, 0 divergences against Icarus Verilog 13.0.
