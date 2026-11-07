// Simulator state: net values, name resolution, and assignment helpers.
//
// Values are held as four-state `Bits`; a design starts fully unknown (x),
// which is what Verilog specifies for regs and wires at time zero.

///|
pub(all) struct Sim {
  net : @elaborate.Netlist
  vals : Array[@value.Bits]
  prev : Array[@value.Bits]
  nba : Array[@value.Bits]
  nba_pending : Array[Bool]
  threads : Array[Thread]
  combs : Array[Comb]
  messages : Array[String]
  mut vcd : @vcd.Writer?
  mut vcd_time : Int64
  mut vcd_started : Bool
  mut time : Int64
  mut finished : Bool
  mut max_delta : Int32
  mut dirty : Bool
}

///|
pub fn Sim::new(net : @elaborate.Netlist) -> Sim {
  let vals : Array[@value.Bits] = []
  let nba : Array[@value.Bits] = []
  let pend : Array[Bool] = []
  for s in net.sigs {
    vals.push(@value.Bits::all_x(s.width))
    nba.push(@value.Bits::all_x(s.width))
    pend.push(false)
  }
  let prev : Array[@value.Bits] = []
  for v in vals {
    prev.push(v)
  }
  let lw = lower_all(net)
  {
    net,
    vals,
    prev,
    nba,
    nba_pending: pend,
    threads: lw.threads,
    combs: lw.combs,
    messages: [],
    vcd: None,
    vcd_time: 0L,
    vcd_started: false,
    time: 0L,
    finished: false,
    max_delta: 100,
    dirty: false,
  }
}

///|
/// Copy the current values into the `prev` snapshot used for edge detection.
pub fn Sim::snapshot(self : Sim) -> Unit {
  let mut i = 0
  for v in self.vals {
    self.prev[i] = v
    i = i + 1
  }
}

///|
/// Resolve a name as seen from `scope`: local nets, then fully qualified nets,
/// then enclosing scopes.
pub fn Sim::lookup(self : Sim, scope : Int32, name : String) -> Int32? {
  net_lookup(self.net, scope, name)
}

///|
/// Name resolution shared with the lowering pass: local nets, then the fully
/// qualified name, then enclosing scopes.
fn net_lookup(net : @elaborate.Netlist, scope : Int32, name : String) -> Int32? {
  let mut sid = scope
  while sid >= 0 {
    match @elaborate.assoc_find(net.scopes[sid].vars, name) {
      Some(id) => return Some(id)
      None => ()
    }
    sid = net.scopes[sid].parent
  }
  @elaborate.find_sig(net, name)
}

///|
fn Sim::sig_width(self : Sim, id : Int32) -> Int32 {
  self.net.sigs[id].width
}

///|
pub fn Sim::read(self : Sim, id : Int32) -> @value.Bits {
  self.vals[id]
}

///|
/// Write a whole net; returns true when the value actually changed.
pub fn Sim::write(self : Sim, id : Int32, v : @value.Bits) -> Bool {
  let cur = self.vals[id]
  if cur.same_bits(v) {
    false
  } else {
    self.vals[id] = v.resize(self.sig_width(id))
    self.dirty = true
    true
  }
}

///|
/// Queue a non-blocking assignment.
fn Sim::write_nba(self : Sim, id : Int32, v : @value.Bits) -> Unit {
  self.nba[id] = v.resize(self.sig_width(id))
  self.nba_pending[id] = true
}

///|
/// Apply all queued non-blocking assignments; returns true when anything moved.
fn Sim::commit_nba(self : Sim) -> Bool {
  let mut changed = false
  let mut i = 0
  for p in self.nba_pending {
    if p {
      if self.write(i, self.nba[i]) {
        changed = true
      }
      self.nba_pending[i] = false
    }
    i = i + 1
  }
  changed
}

///|
/// Assign to a (possibly selected) lvalue.
fn Sim::write_lvalue(
  self : Sim,
  scope : Int32,
  lv : @ast.LValue,
  v : @value.Bits,
) -> Bool {
  match self.lookup(scope, lv.name) {
    None => false
    Some(id) => {
      let w = self.sig_width(id)
      match lv.sel {
        @ast.Whole => self.write(id, v)
        @ast.Bit(idx) => {
          let i = self.eval_int(scope, idx)
          let cur = self.vals[id]
          let mut out = cur
          let bit = if i >= 0 && i < w { v.bit_at(0) } else { @value.X }
          out = out.set_part(i, i, @value.Bits::from_logic(bit, 1))
          self.write(id, out)
        }
        @ast.Part(hi, lo) => {
          let h = self.eval_int(scope, hi)
          let l = self.eval_int(scope, lo)
          let cur = self.vals[id]
          let out = cur.set_part(h, l, v)
          self.write(id, out)
        }
      }
    }
  }
}

///|
fn Sim::eval_int(self : Sim, scope : Int32, e : @ast.Expr) -> Int32 {
  let v = self.eval(scope, e, 32)
  if v.is_known() {
    v.to_int()
  } else {
    0
  }
}

///|
pub fn Sim::log(self : Sim, msg : String) -> Unit {
  self.messages.push(msg)
}

///|
/// Attach a VCD writer; changes from here on are recorded.
pub fn Sim::attach_vcd(self : Sim, w : @vcd.Writer) -> Unit {
  self.vcd = Some(w)
}

///|
/// Write the VCD preamble and the time-zero values.
pub fn Sim::dump_initial(self : Sim) -> Unit {
  match self.vcd {
    None => ()
    Some(w) => {
      w.header()
      w.begin_dumpvars()
      w.time_marker(0L)
      let mut i = 0
      while i < self.vals.length() {
        w.value(i, self.vals[i])
        i = i + 1
      }
      w.end_dumpvars()
      self.vcd_time = 0L
      self.vcd_started = true
    }
  }
}

///|
/// Record every value that moved during the last delta cycle.
pub fn Sim::trace(self : Sim) -> Unit {
  match self.vcd {
    None => ()
    Some(w) => {
      let mut emitted = false
      let mut i = 0
      while i < self.vals.length() {
        if !self.vals[i].same_bits(self.prev[i]) {
          if !emitted && (!self.vcd_started || self.vcd_time != self.time) {
            w.time_marker(self.time)
            self.vcd_time = self.time
            self.vcd_started = true
          }
          emitted = true
          w.value(i, self.vals[i])
        }
        i = i + 1
      }
    }
  }
}
