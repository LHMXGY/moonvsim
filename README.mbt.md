# moonvsim

A **MoonBit-native four-state event-driven RTL simulator for Verilog-2001**.

`moonvsim` reads a synthesizable Verilog subset plus a testbench, elaborates the
design hierarchy, and runs it as a discrete-event simulation. It writes
standard VCD traces, so every waveform viewer (GTKWave, Surfer, VS Code
WaveTrace) can open the results, and it can be cross-checked bit-for-bit
against Icarus Verilog.

```
$ moonvsim run counter_tb.v --top counter_tb --vcd out.vcd --stop-time 200
[tb] reset asserted
[tb] count=0
[tb] count=1
...
moonvsim: 200 ns elapsed, 13 clock cycles, 0 errors
```

## Why another simulator

MoonBit already has Verilog *linters* (`moonbit-rtl`), VCD readers
(`moonbit-vcd`, `minivcd_mbt`), an analog SPICE solver
(`moonbit-circuit-solver`), Gerber tooling and even an EtherCAT master, but no
digital RTL execution engine. `moonvsim` is that missing keystone: it turns a
design into events, not just diagnostics.

## Status

| Milestone | State |
| --- | --- |
| Four-state bit vectors, 64-bit, x/z propagation | done |
| Verilog-2001 lexer and parser | in progress |
| Elaboration (parameters, widths, hierarchy) | planned |
| Event scheduler and simulation kernel | planned |
| VCD writer | planned |
| CLI and browser playground | planned |
| Differential test suite against Icarus Verilog | planned |

## Layout

```
src/value/      four-state bit vectors, arithmetic, formatting
src/ast/        HDL syntax tree
src/lexer/      tokenizer
src/parser/     Verilog-2001 parser
src/elaborate/  parameters, widths, hierarchy
src/sched/      event scheduler
src/sim/        simulation kernel, nets, processes, VCD tracing
src/vcd/        Value Change Dump writer
src/cmd/        command line interface
src/web/        browser demo
test/           Verilog designs and expected traces
```

## Build

```sh
moon build --target native     # CLI
moon build --target wasm-gc    # browser demo
moon test                      # unit tests
```

## License

Apache-2.0. See [LICENSE](LICENSE).
