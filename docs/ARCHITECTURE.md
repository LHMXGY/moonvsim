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
     [elaborate] hierarchy, parameters, widths, constant folding
            |
         [sched]  event queue (active / inactive / nba regions)
            |
          [sim]   nets, processes, delays
           /   \
      [vcd]    [cli|web]
```

## Four-state values

`Bits` stores four planes of a value up to 64 bits wide:

| field | meaning |
| --- | --- |
| `val` | bits known to be 1 |
| `unk` | bits that are 0/1 unknown |
| `zed` | subset of `unk` that is high impedance |

Every operator implements IEEE 1364 four-state tables. Unknown propagation is
explicit rather than "all or nothing": `4'b1x01 & 4'b1010` is `4'b10x0`.

## Event scheduling

Verilog's stratified event queue is modelled directly:

1. active events (blocking assignments, gate evaluation),
2. inactive events (`#0`),
3. non-blocking assignment updates,
4. monitors (`$display`, `$strobe`).

Time advances to the earliest pending event. A time step repeats until all
queues are empty, which is what makes `always @(posedge clk)` and
non-blocking flops behave correctly.

## Determinism

Processes are scheduled in a stable order derived from declaration order, so
two runs of the same design produce byte-identical VCD. This makes the
differential oracle meaningful.

## Conformance oracle

`test/conformance/run.py` compiles each design with both `iverilog` and
`moonvsim`, runs both with the same testbench, and compares VCD value changes
per signal per timestamp. Divergences are reported as a table.
