// moonvsim — a MoonBit-native Verilog-2001 RTL simulator.
//
// Module layout (see docs/ARCHITECTURE.md):
//   src/value      four-state bit vectors and formatting
//   src/ast        HDL syntax tree
//   src/lexer      tokenizer
//   src/parser     Verilog-2001 parser
//   src/elaborate  design elaboration (parameters, widths, hierarchy)
//   src/sched      event scheduler
//   src/sim        simulation kernel (nets, processes, VCD tracing)
//   src/vcd        Value Change Dump writer/reader
//   src/cmd        command line interface
//   src/web        browser demo (wasm-gc)

name = "moonvsim/moonvsim"

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = ["verilog", "rtl", "simulator", "eda", "hdl"]

preferred_target = "wasm-gc"

description = "A MoonBit-native four-state event-driven Verilog-2001 RTL simulator"

import {
  "moonbitlang/x@0.5.7",
}
