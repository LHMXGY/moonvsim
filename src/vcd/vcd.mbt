// VCD (Value Change Dump) writer.
//
// The writer is deliberately independent of the simulator: it only needs the
// signal names, their widths and the four-state values.  Hierarchical names
// such as `top.u1.q` become nested `$scope` blocks so that GTKWave and
// Surfer show the same tree as a commercial simulator would.

pub(all) struct Writer {
  names : Array[String]
  widths : Array[Int32]
  ids : Array[String]
  sb : StringBuilder
}

fn code_of(n : Int32) -> String {
  // VCD identifiers may be any printable ASCII; we restrict them to
  // [0-9A-Za-z] so that an id can never be confused with the `#<time>` and
  // `$keyword` tokens that structure the file (the naive '!'-based scheme
  // produces '#' and '$' for the third and fourth signal, which breaks
  // readers that look at the first character).
  let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  let sb = StringBuilder()
  let mut k = n + 1
  while k > 0 {
    let d = (k - 1) % 62
    sb.write_char(match alphabet.get_char(d) {
      Some(c) => c
      None => '0'
    })
    k = (k - 1) / 62
  }
  sb.to_string()
}

fn split_dots(name : String) -> Array[String] {
  let out : Array[String] = []
  let sb = StringBuilder()
  let mut i = 0
  while i < name.length() {
    let c = match name.get_char(i) {
      Some(ch) => ch
      None => '.'
    }
    if c == '.' {
      out.push(sb.to_string())
      sb.reset()
    } else {
      sb.write_char(c)
    }
    i = i + 1
  }
  out.push(sb.to_string())
  out
}

pub fn Writer::new(names : Array[String], widths : Array[Int32]) -> Writer {
  let ids : Array[String] = []
  let mut i = 0
  for _ in names {
    ids.push(code_of(i))
    i = i + 1
  }
  {
    names: names,
    widths: widths,
    ids: ids,
    sb: StringBuilder(),
  }
}

fn Writer::open_scope(self : Writer, name : String) -> Unit {
  self.sb.write_string("$scope module ")
  self.sb.write_string(name)
  self.sb.write_string(" $end\n")
}

fn Writer::close_scope(self : Writer) -> Unit {
  self.sb.write_string("$upscope $end\n")
}

fn Writer::declare_var(self : Writer, idx : Int32, leaf : String) -> Unit {
  self.sb.write_string("$var wire ")
  self.sb.write_string(self.widths[idx].to_string())
  self.sb.write_char(' ')
  self.sb.write_string(self.ids[idx])
  self.sb.write_char(' ')
  self.sb.write_string(leaf)
  self.sb.write_string(" $end\n")
}

/// Write the preamble (metadata, `$scope` tree, `$var` table).
pub fn Writer::header(self : Writer) -> Unit {
  self.sb.write_string("$version moonvsim $end\n")
  self.sb.write_string("$timescale 1ns $end\n")
  let path : Array[String] = []
  let mut i = 0
  while i < self.names.length() {
    let segs = split_dots(self.names[i])
    let leaf = segs[segs.length() - 1]
    // Close scopes until the current path is a proper prefix of segs.
    let mut keep = path.length()
    if keep > segs.length() - 1 {
      keep = segs.length() - 1
    }
    let mut common = 0
    while common < keep {
      if path[common] != segs[common] {
        keep = common
        common = keep
      } else {
        common = common + 1
      }
    }
    while path.length() > keep {
      self.close_scope()
      let _ = path.pop()
    }
    let mut k = path.length()
    while k < segs.length() - 1 {
      self.open_scope(segs[k])
      path.push(segs[k])
      k = k + 1
    }
    self.declare_var(i, leaf)
    i = i + 1
  }
  while path.length() > 0 {
    self.close_scope()
    let _ = path.pop()
  }
  self.sb.write_string("$enddefinitions $end\n")
}

/// Emit a `#time` marker; the caller decides when a new timestamp is needed.
pub fn Writer::time_marker(self : Writer, time : Int64) -> Unit {
  self.sb.write_char('#')
  self.sb.write_string(time.to_string())
  self.sb.write_char('\n')
}

/// Emit one value change (`0!`/`1!` for scalars, `b1010 !` for vectors).
pub fn Writer::value(self : Writer, id : Int32, v : @value.Bits) -> Unit {
  if self.widths[id] == 1 {
    self.sb.write_char(v.bit_at(0).to_char())
    self.sb.write_char(' ')
    self.sb.write_string(self.ids[id])
    self.sb.write_char('\n')
  } else {
    self.sb.write_char('b')
    self.sb.write_string(v.to_bin_string())
    self.sb.write_char(' ')
    self.sb.write_string(self.ids[id])
    self.sb.write_char('\n')
  }
}

pub fn Writer::begin_dumpvars(self : Writer) -> Unit {
  self.sb.write_string("$dumpvars\n")
}

pub fn Writer::end_dumpvars(self : Writer) -> Unit {
  self.sb.write_string("$end\n")
}

pub fn Writer::text(self : Writer) -> String {
  self.sb.to_string()
}
