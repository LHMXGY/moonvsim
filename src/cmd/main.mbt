// moonvsim command line interface.
//
//   moonvsim run <file.v> [--top NAME] [--vcd out.vcd] [--max-time N]

///|
fn usage() -> Unit {
  println("moonvsim - a four-state Verilog-2001 simulator written in MoonBit")
  println("")
  println("usage: moonvsim run <file.v> [options]")
  println("")
  println("options:")
  println(
    "  --top NAME       top module (default: module named top, else the last one)",
  )
  println("  --vcd PATH       write a value change dump to PATH")
  println("  --max-time N     stop at simulation time N (default 1000)")
}

///|
fn main {
  let argv = @env.args()
  if argv.length() < 2 {
    usage()
    return
  }
  let mut i = 1
  let mut file = ""
  let mut top = ""
  let mut vcd_path = ""
  let mut max_time = 1000L
  while i < argv.length() {
    let a = argv[i]
    if a == "--top" && i + 1 < argv.length() {
      top = argv[i + 1]
      i = i + 2
    } else if a == "--vcd" && i + 1 < argv.length() {
      vcd_path = argv[i + 1]
      i = i + 2
    } else if a == "--max-time" && i + 1 < argv.length() {
      max_time = parse_time(argv[i + 1])
      i = i + 2
    } else if a == "run" || a == "--help" || a == "-h" {
      if a != "run" {
        usage()
        return
      }
      i = i + 1
    } else {
      file = a
      i = i + 1
    }
  }
  if file == "" {
    usage()
    return
  }
  let src = @fs.read_file_to_string(file) catch {
    _ => {
      println("moonvsim: cannot read \{file}")
      return
    }
  }
  let (design, perrs) = @parser.parse(src)
  for e in perrs {
    println("moonvsim: \{e}")
  }
  let net = @elaborate.elaborate_top(design, top)
  for e in net.errors {
    println("moonvsim: \{e}")
  }
  if net.sigs.length() == 0 {
    println("moonvsim: nothing to simulate")
    return
  }
  let sim = @sim.Sim::new(net)
  if vcd_path != "" {
    let names : Array[String] = []
    let widths : Array[Int32] = []
    for s in net.sigs {
      names.push(s.name)
      widths.push(s.width)
    }
    let w = @vcd.Writer::new(names, widths)
    sim.attach_vcd(w)
    sim.dump_initial()
  }
  sim.run(max_time)
  for m in sim.messages {
    println(m)
  }
  if vcd_path != "" {
    match sim.vcd {
      Some(w) =>
        try {
          @fs.write_string_to_file(vcd_path, w.text())
          println("moonvsim: wrote \{vcd_path}")
        } catch {
          _ => println("moonvsim: cannot write \{vcd_path}")
        }
      None => ()
    }
  }
  println(
    "moonvsim: \{net.sigs.length()} nets, \{net.procs.length()} processes, stopped at t=\{sim.time}",
  )
}

///|
fn parse_time(s : String) -> Int64 {
  let mut t = 0L
  let mut i = 0
  while i < s.length() {
    let c = match s.get_char(i) {
      Some(ch) => ch
      None => '0'
    }
    if c >= '0' && c <= '9' {
      t = t * 10L + (c.to_int() - '0'.to_int()).to_int64()
    }
    i = i + 1
  }
  t
}
