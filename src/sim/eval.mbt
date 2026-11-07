// Expression evaluation with Verilog width/signedness rules.
//
// `eval(scope, e, ctx)` evaluates `e` in a context that is `ctx` bits wide.
// Arithmetic and bitwise operators extend their operands to the widest
// operand *or* the context, which is what makes `assign s[8:0] = a + b` keep
// the carry out of an 8-bit add.

fn max3(a : Int32, b : Int32, c : Int32) -> Int32 {
  let mut m = a
  if b > m {
    m = b
  }
  if c > m {
    m = c
  }
  m
}

fn Sim::width_of(self : Sim, scope : Int32, e : @ast.Expr) -> Int32 {
  match e {
    @ast.Number(l) => l.bits.width
    @ast.Str(_) => 0
    @ast.Ident(n) =>
      match self.lookup(scope, n) {
        Some(id) => self.sig_width(id)
        None =>
          match self.const_of(scope, n) {
            Some(b) => b.width
            None => 1
          }
      }
    @ast.BitSel(_, _) => 1
    @ast.PartSel(_, hi, lo) => {
      let h = self.eval_int(scope, hi)
      let l = self.eval_int(scope, lo)
      let d = if h >= l { h - l } else { l - h }
      d + 1
    }
    @ast.Unary(op, a) =>
      match op {
        @ast.RedAnd | @ast.RedOr | @ast.RedXor | @ast.Not => 1
        _ => self.width_of(scope, a)
      }
    @ast.Binary(op, a, b) =>
      match op {
        @ast.LogAnd | @ast.LogOr | @ast.Eq | @ast.Ne | @ast.CaseEq | @ast.CaseNe | @ast.Lt | @ast.Le | @ast.Gt | @ast.Ge =>
          1
        @ast.Shl | @ast.Shr | @ast.Ashr => self.width_of(scope, a)
        _ => {
          let wa = self.width_of(scope, a)
          let wb = self.width_of(scope, b)
          if wa >= wb {
            wa
          } else {
            wb
          }
        }
      }
    @ast.Cond(_, a, b) => {
      let wa = self.width_of(scope, a)
      let wb = self.width_of(scope, b)
      if wa >= wb {
        wa
      } else {
        wb
      }
    }
    @ast.Concat(items) => {
      let mut w = 0
      for it in items {
        w = w + self.width_of(scope, it)
      }
      w
    }
    @ast.Repl(n, items) => {
      let mut w = 0
      for it in items {
        w = w + self.width_of(scope, it)
      }
      let c = self.eval_int(scope, n)
      w * (if c > 0 { c } else { 0 })
    }
    @ast.Call(name, args) =>
      match name {
        "$clog2" => 32
        "$signed" =>
          match args {
            [a, ..] => self.width_of(scope, a)
            _ => 32
          }
        "$unsigned" =>
          match args {
            [a, ..] => self.width_of(scope, a)
            _ => 32
          }
        _ => 32
      }
  }
}

/// Look up a parameter visible from `scope`.
fn Sim::const_of(self : Sim, scope : Int32, name : String) -> @value.Bits? {
  let mut sid = scope
  while sid >= 0 {
    match @elaborate.assoc_find(self.net.scopes[sid].consts, name) {
      Some(v) => return Some(v)
      None => sid = self.net.scopes[sid].parent
    }
  }
  None
}

fn widen(v : @value.Bits, ctx : Int32) -> @value.Bits {
  if ctx > v.width {
    v.resize(ctx)
  } else {
    v
  }
}

fn Sim::eval(self : Sim, scope : Int32, e : @ast.Expr, ctx : Int32) -> @value.Bits {
  match e {
    @ast.Number(l) => widen(l.bits, ctx)
    @ast.Str(s) => @value.Bits::from_bytes_string(s)
    @ast.Ident(n) =>
      match self.lookup(scope, n) {
        Some(id) => {
          let v = widen(self.vals[id], ctx)
          if self.net.sigs[id].signed {
            v.with_signed(true)
          } else {
            v
          }
        }
        None =>
          match self.const_of(scope, n) {
            Some(b) => widen(b, ctx)
            None => {
              @value.Bits::all_x(ctx)
            }
          }
      }
    @ast.BitSel(base, idx) => {
      let bv = self.eval(scope, base, self.width_of(scope, base))
      let i = self.eval_int(scope, idx)
      @value.Bits::from_logic(bv.bit_at(i), 1)
    }
    @ast.PartSel(base, hi, lo) => {
      let bv = self.eval(scope, base, self.width_of(scope, base))
      let h = self.eval_int(scope, hi)
      let l = self.eval_int(scope, lo)
      bv.part_sel(h, l)
    }
    @ast.Unary(op, a) =>
      match op {
        @ast.RedAnd => self.eval(scope, a, self.width_of(scope, a)).red_and()
        @ast.RedOr => self.eval(scope, a, self.width_of(scope, a)).red_or()
        @ast.RedXor => self.eval(scope, a, self.width_of(scope, a)).red_xor()
        @ast.Not => self.eval(scope, a, self.width_of(scope, a)).lnot()
        _ => {
          let w = max3(self.width_of(scope, a), 1, ctx)
          let av = self.eval(scope, a, w)
          match op {
            @ast.Plus => av
            @ast.Minus => av.bneg()
            _ => av.bnot()
          }
        }
      }
    @ast.Binary(op, a, b) =>
      match op {
        @ast.LogAnd => self.eval(scope, a, 1).land(self.eval(scope, b, 1))
        @ast.LogOr => self.eval(scope, a, 1).lor(self.eval(scope, b, 1))
        @ast.Shl | @ast.Shr | @ast.Ashr => {
          let w = max3(self.width_of(scope, a), 1, ctx)
          let av = self.eval(scope, a, w)
          let sh = self.eval_int(scope, b)
          match op {
            @ast.Shl => av.bshl(@value.Bits::from_uint(sh.reinterpret_as_uint().to_uint64(), 32))
            @ast.Shr => av.bshr(@value.Bits::from_uint(sh.reinterpret_as_uint().to_uint64(), 32))
            _ => av.bashr(@value.Bits::from_uint(sh.reinterpret_as_uint().to_uint64(), 32))
          }
        }
        @ast.Eq | @ast.Ne | @ast.CaseEq | @ast.CaseNe | @ast.Lt | @ast.Le | @ast.Gt | @ast.Ge => {
          let wa = self.width_of(scope, a)
          let wb = self.width_of(scope, b)
          let w = if wa >= wb { wa } else { wb }
          let av = self.eval(scope, a, w)
          let bv = self.eval(scope, b, w)
          match op {
            @ast.Eq => av.beq(bv)
            @ast.Ne => av.bne(bv)
            @ast.CaseEq => av.bcase_eq(bv)
            @ast.CaseNe => av.bcase_ne(bv)
            @ast.Lt => av.blt(bv)
            @ast.Le => av.ble(bv)
            @ast.Gt => av.bgt(bv)
            _ => av.bge(bv)
          }
        }
        _ => {
          let w = max3(self.width_of(scope, a), self.width_of(scope, b), ctx)
          let av = self.eval(scope, a, w)
          let bv = self.eval(scope, b, w)
          match op {
            @ast.Add => av.badd(bv)
            @ast.Sub => av.bsub(bv)
            @ast.Mul => av.bmul(bv)
            @ast.Div => av.bdiv(bv)
            @ast.Mod => av.bmod(bv)
            @ast.Pow => av.bpow(bv)
            @ast.BitAnd => av.band(bv)
            @ast.BitOr => av.bor(bv)
            @ast.BitXor => av.bxor(bv)
            _ => av.bxnor(bv)
          }
        }
      }
    @ast.Cond(c, a, b) => {
      let cv = self.eval(scope, c, 1)
      if cv.truth() == Some(true) {
        self.eval(scope, a, ctx)
      } else {
        self.eval(scope, b, ctx)
      }
    }
    @ast.Concat(items) => {
      let mut acc = @value.Bits::zero(0)
      for it in items {
        let w = self.width_of(scope, it)
        acc = acc.concat(self.eval(scope, it, w))
      }
      if ctx > 0 && ctx < acc.width {
        acc.part_sel(ctx - 1, 0)
      } else {
        widen(acc, ctx)
      }
    }
    @ast.Repl(n, items) => {
      let mut one = @value.Bits::zero(0)
      for it in items {
        let w = self.width_of(scope, it)
        one = one.concat(self.eval(scope, it, w))
      }
      let c = self.eval_int(scope, n)
      let mut acc = @value.Bits::zero(0)
      let mut i = 0
      while i < c {
        acc = acc.concat(one)
        i = i + 1
      }
      widen(acc, ctx)
    }
    @ast.Call(name, args) => {
      match (name, args) {
        ("$signed", [a, ..]) => {
          let w = self.width_of(scope, a)
          self.eval(scope, a, w).with_signed(true)
        }
        ("$unsigned", [a, ..]) => {
          let w = self.width_of(scope, a)
          self.eval(scope, a, w).with_signed(false)
        }
        ("$clog2", [a, ..]) => {
          let v = self.eval_int(scope, a)
          let mut n = 0
          let mut p = 1
          while p < v {
            p = p * 2
            n = n + 1
          }
          @value.Bits::from_uint(n.reinterpret_as_uint().to_uint64(), 32)
        }
        (_, _) => @value.Bits::all_x(ctx)
      }
    }
  }
}

/// Evaluate and truncate to `width`, as an assignment does.
pub fn Sim::eval_sized(self : Sim, scope : Int32, e : @ast.Expr, width : Int32) -> @value.Bits {
  let v = self.eval(scope, e, width)
  if v.width == width {
    v
  } else if width >= v.width {
    v.resize(width)
  } else {
    v.part_sel(width - 1, 0)
  }
}
