// Elaboration: flatten a module hierarchy into a netlist plus a process list.
//
// Every net (port, wire, reg, integer) is a `Sig` with a fully qualified name
// such as `counter.u_add.sum`.  Instance ports are connected by inserting
// continuous assignments, which keeps the simulator free of hierarchy logic:
// it only ever sees top-level nets and top-level processes.

///|
/// A lexical scope introduced by one module instance.
pub(all) struct Scope {
  prefix : String
  parent : Int32
  vars : Array[(String, Int32)]
  consts : Array[(String, @value.Bits)]
  funcs : Array[@ast.Function]
}

///|
/// A flattened net.
pub(all) struct Sig {
  name : String
  width : Int32
  signed : Bool
}

///|
/// A flattened process (`always` / `initial`).
pub(all) struct Proc {
  scope : Int32
  kind : @ast.ProcessKind
  body : @ast.Stmt
}

///|
/// The elaborated design.
pub(all) struct Netlist {
  sigs : Array[Sig]
  scopes : Array[Scope]
  assigns : Array[@ast.ContAssign]
  assign_scope : Array[Int32]
  procs : Array[Proc]
  errors : Array[String]
}

///|
/// Look up a key in a small association list.
pub fn[V] assoc_find(xs : Array[(String, V)], k : String) -> V? {
  for p in xs {
    if p.0 == k {
      return Some(p.1)
    }
  }
  None
}

///|
/// Replace (or append) a key in a small association list.
fn[V] assoc_set(xs : Array[(String, V)], k : String, v : V) -> Unit {
  let mut i = 0
  for p in xs {
    if p.0 == k {
      xs[i] = (k, v)
      return
    }
    i = i + 1
  }
  xs.push((k, v))
}

///|
priv struct Builder {
  sigs : Array[Sig]
  scopes : Array[Scope]
  assigns : Array[@ast.ContAssign]
  assign_scope : Array[Int32]
  procs : Array[Proc]
  errors : Array[String]
  modtab : Array[(String, @ast.Module)]
  sigidx : Array[(String, Int32)]
}

///|
pub fn elaborate(design : @ast.Design) -> Netlist {
  elaborate_top(design, "")
}

///|
/// Elaborate `design` using `top_name`, or the module named `top`, or the last
/// module when neither exists.
pub fn elaborate_top(design : @ast.Design, top_name : String) -> Netlist {
  let b = Builder::new(design.modules)
  let mut top : @ast.Module? = None
  if top_name != "" {
    top = assoc_find(b.modtab, top_name)
    if top is None {
      b.errors.push("[elab] unknown top module '\{top_name}'")
    }
  }
  if top is None {
    top = assoc_find(b.modtab, "top")
  }
  if top is None && design.modules.length() > 0 {
    top = Some(design.modules[design.modules.length() - 1])
  }
  match top {
    Some(m) => b.elab_module("", m, -1, [], -1) |> ignore
    None => b.errors.push("[elab] design has no modules")
  }
  {
    sigs: b.sigs,
    scopes: b.scopes,
    assigns: b.assigns,
    assign_scope: b.assign_scope,
    procs: b.procs,
    errors: b.errors,
  }
}

///|
fn Builder::new(mods : Array[@ast.Module]) -> Builder {
  let tab : Array[(String, @ast.Module)] = []
  for m in mods {
    assoc_set(tab, m.name, m)
  }
  {
    sigs: [],
    scopes: [],
    assigns: [],
    assign_scope: [],
    procs: [],
    errors: [],
    modtab: tab,
    sigidx: [],
  }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

///|
fn Builder::lookup_const(
  self : Builder,
  scope : Int32,
  name : String,
) -> @value.Bits? {
  let mut sid = scope
  while sid >= 0 {
    match assoc_find(self.scopes[sid].consts, name) {
      Some(v) => return Some(v)
      None => sid = self.scopes[sid].parent
    }
  }
  None
}

///|
/// Evaluate a constant expression, if it only depends on parameters.
fn Builder::const_bits(
  self : Builder,
  scope : Int32,
  e : @ast.Expr,
) -> @value.Bits? {
  match e {
    @ast.Number(l) => Some(l.bits)
    @ast.Ident(n) => self.lookup_const(scope, n)
    @ast.Unary(op, a) =>
      match self.const_bits(scope, a) {
        Some(b) =>
          match op {
            @ast.Plus => Some(b)
            @ast.Minus => Some(b.bneg())
            @ast.BitNot => Some(b.bnot())
            @ast.Not => Some(b.lnot())
            @ast.RedAnd => Some(b.red_and())
            @ast.RedOr => Some(b.red_or())
            @ast.RedXor => Some(b.red_xor())
          }
        None => None
      }
    @ast.Binary(op, a, b) =>
      match (self.const_bits(scope, a), self.const_bits(scope, b)) {
        (Some(x), Some(y)) =>
          match op {
            @ast.Add => Some(x.badd(y))
            @ast.Sub => Some(x.bsub(y))
            @ast.Mul => Some(x.bmul(y))
            @ast.Div => Some(x.bdiv(y))
            @ast.Mod => Some(x.bmod(y))
            @ast.Shl => Some(x.bshl(y))
            @ast.Shr => Some(x.bshr(y))
            @ast.Ashr => Some(x.bashr(y))
            @ast.BitAnd => Some(x.band(y))
            @ast.BitOr => Some(x.bor(y))
            @ast.BitXor => Some(x.bxor(y))
            @ast.BitXnor => Some(x.bxnor(y))
            @ast.Pow => Some(x.bpow(y))
            _ => None
          }
        _ => None
      }
    @ast.Cond(c, a, b) =>
      match self.const_bits(scope, c) {
        Some(v) =>
          if v.truth() == Some(true) {
            self.const_bits(scope, a)
          } else {
            self.const_bits(scope, b)
          }
        None => None
      }
    @ast.Concat(items) => {
      let mut acc : @value.Bits? = Some(@value.Bits::zero(0))
      for it in items {
        match (acc, self.const_bits(scope, it)) {
          (Some(a), Some(b)) => acc = Some(a.concat(b))
          _ => acc = None
        }
      }
      acc
    }
    _ => None
  }
}

///|
fn Builder::const_int(self : Builder, scope : Int32, e : @ast.Expr) -> Int32? {
  match self.const_bits(scope, e) {
    Some(b) => Some(b.to_int())
    None => None
  }
}

// ---------------------------------------------------------------------------
// Nets and scopes
// ---------------------------------------------------------------------------

///|
fn Builder::add_sig(
  self : Builder,
  name : String,
  width : Int32,
  signed : Bool,
) -> Int32 {
  let w = if width < 1 { 1 } else { width }
  let id = self.sigs.length()
  self.sigs.push({ name, width: w, signed, })
  assoc_set(self.sigidx, name, id)
  id
}

///|
/// Resolve the width of a declared range such as `[7:0]` or `[W-1:0]`.
fn Builder::range_width(
  self : Builder,
  scope : Int32,
  r : (@ast.Expr, @ast.Expr)?,
) -> Int32 {
  match r {
    None => 1
    Some((hi, lo)) =>
      match (self.const_int(scope, hi), self.const_int(scope, lo)) {
        (Some(a), Some(b)) => {
          let d = if a >= b { a - b } else { b - a }
          d + 1
        }
        _ => {
          self.errors.push("[elab] range bound is not a constant")
          1
        }
      }
  }
}

///|
fn var_kind_is_net(k : @ast.VarKind) -> Bool {
  match k {
    @ast.Wire | @ast.Logic => true
    _ => false
  }
}

///|
fn var_kind_is_integer(k : @ast.VarKind) -> Bool {
  match k {
    @ast.Integer => true
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Module instantiation
// ---------------------------------------------------------------------------

///|
fn Builder::elab_module(
  self : Builder,
  prefix : String,
  m : @ast.Module,
  parent : Int32,
  overrides : Array[(String?, @ast.Expr)],
  over_scope : Int32,
) -> Int32 {
  let sid = self.scopes.length()
  let scope = { prefix, parent, vars: [], consts: [], funcs: m.functions, }
  self.scopes.push(scope)

  // Parameters: overrides first, then defaults.
  let mut pos = 0
  for p in m.params {
    let mut chosen : @ast.Expr? = None
    for ov in overrides {
      match ov {
        (Some(n), e) => if n == p.name { chosen = Some(e) }
        (None, e) =>
          if pos == index_of_param(m.params, p.name) {
            chosen = Some(e)
          }
      }
    }
    pos = pos + 1
    let v = match chosen {
      Some(e) =>
        match self.const_bits(over_scope, e) {
          Some(b) => b
          None => {
            self.errors.push(
              "[elab] parameter '\{p.name}' override is not constant",
            )
            @value.Bits::zero(1)
          }
        }
      None =>
        match self.const_bits(sid, p.value) {
          Some(b) => b
          None => {
            self.errors.push(
              "[elab] parameter '\{p.name}' default is not constant",
            )
            @value.Bits::zero(1)
          }
        }
    }
    assoc_set(self.scopes[sid].consts, p.name, v)
  }

  // Nets.
  for port in m.ports {
    let w = self.range_width(sid, port.range)
    for name in port.names {
      let id = self.add_sig(prefix + name, w, port.signed)
      assoc_set(self.scopes[sid].vars, name, id)
    }
  }
  for v in m.vars {
    let w = if var_kind_is_integer(v.kind) {
      32
    } else {
      self.range_width(sid, v.range)
    }
    let signed = var_kind_is_integer(v.kind) || v.signed
    for name in v.names {
      let id = self.add_sig(prefix + name, w, signed)
      assoc_set(self.scopes[sid].vars, name, id)
    }
  }

  // Declaration initialisers.  `wire a = e;` is a continuous assignment,
  // while `reg a = e;` is an initial assignment performed at time zero, as
  // described by IEEE 1364-2005 section 6.2.2.
  for v in m.vars {
    match v.init {
      Some(e) =>
        if v.names.length() > 0 {
          let lv : @ast.LValue = { name: v.names[0], sel: @ast.Whole, }
          if var_kind_is_net(v.kind) {
            self.assigns.push({ lhs: lv, rhs: e, })
            self.assign_scope.push(sid)
          } else {
            let body = @ast.Block([@ast.Assign(@ast.Blocking, lv, e)])
            self.procs.push({ scope: sid, kind: @ast.Initial, body, })
          }
        }
      None => ()
    }
  }

  for a in m.assigns {
    self.assigns.push(a)
    self.assign_scope.push(sid)
  }
  for p in m.processes {
    self.procs.push({ scope: sid, kind: p.kind, body: p.body, })
  }
  for inst in m.instances {
    match assoc_find(self.modtab, inst.module_name) {
      Some(child) => {
        let cprefix = prefix + inst.instance_name + "."
        let csid = self.elab_module(cprefix, child, sid, inst.params, sid)
        self.connect_ports(sid, csid, child, inst, cprefix)
      }
      None => self.errors.push("[elab] unknown module '\{inst.module_name}'")
    }
  }
  sid
}

///|
fn index_of_param(params : Array[@ast.ParamDecl], name : String) -> Int32 {
  let mut i = 0
  for p in params {
    if p.name == name {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Insert the continuous assignments that bind an instance's ports.
fn Builder::connect_ports(
  self : Builder,
  parent_scope : Int32,
  child_scope : Int32,
  child : @ast.Module,
  inst : @ast.Instance,
  cprefix : String,
) -> Unit {
  let _ = child_scope
  let mut pos = 0
  for port in child.ports {
    for name in port.names {
      let conn = self.find_conn(inst, name, pos)
      pos = pos + 1
      match conn {
        Some(c) =>
          match c.expr {
            Some(e) =>
              match port.dir {
                @ast.Input => {
                  self.assigns.push({
                    lhs: { name: cprefix + name, sel: @ast.Whole, },
                    rhs: e,
                  })
                  self.assign_scope.push(parent_scope)
                }
                @ast.Output =>
                  match expr_to_lvalue(e) {
                    Some(lv) => {
                      self.assigns.push({
                        lhs: lv,
                        rhs: @ast.Ident(cprefix + name),
                      })
                      self.assign_scope.push(parent_scope)
                    }
                    None =>
                      self.errors.push(
                        "[elab] output port '\{name}' must connect to a net, not an expression",
                      )
                  }
                @ast.Inout => ()
              }
            None => ()
          }
        None => ()
      }
    }
  }
}

///|
fn Builder::find_conn(
  self : Builder,
  inst : @ast.Instance,
  name : String,
  pos : Int32,
) -> @ast.PortConn? {
  let _ = self
  for c in inst.ports {
    match c.name {
      Some(n) => if n == name { return Some(c) }
      None => ()
    }
  }
  let mut i = 0
  for c in inst.ports {
    if c.name is None {
      if i == pos {
        return Some(c)
      }
      i = i + 1
    }
  }
  None
}

///|
fn expr_to_lvalue(e : @ast.Expr) -> @ast.LValue? {
  match e {
    @ast.Ident(n) => Some({ name: n, sel: @ast.Whole, })
    @ast.BitSel(base, idx) =>
      match base {
        @ast.Ident(n) => Some({ name: n, sel: @ast.Bit(idx), })
        _ => None
      }
    @ast.PartSel(base, hi, lo) =>
      match base {
        @ast.Ident(n) => Some({ name: n, sel: @ast.Part(hi, lo), })
        _ => None
      }
    _ => None
  }
}

///|
/// Find a net by fully qualified name.
pub fn find_sig(net : Netlist, name : String) -> Int32? {
  let mut i = 0
  for s in net.sigs {
    if s.name == name {
      return Some(i)
    }
    i = i + 1
  }
  None
}
