// Recursive-descent parser for the Verilog-2001 synthesizable subset.

pub struct Parser {
  toks : Array[@lexer.Token]
  mut pos : Int32
  errors : Array[String]
}

pub fn Parser::new(toks : Array[@lexer.Token]) -> Parser {
  { toks: toks, pos: 0, errors: [] }
}

fn Parser::cur(self : Parser) -> @lexer.Token {
  if self.pos < self.toks.length() {
    self.toks[self.pos]
  } else {
    { kind: @lexer.Eof, line: 0, col: 0 }
  }
}

fn Parser::cur_kind(self : Parser) -> @lexer.TokenKind {
  self.cur().kind
}

fn Parser::advance(self : Parser) -> Unit {
  if self.pos < self.toks.length() - 1 {
    self.pos = self.pos + 1
  } else {
    self.pos = self.toks.length() - 1
  }
}

fn Parser::error(self : Parser, msg : String) -> Unit {
  let t = self.cur()
  self.errors.push("[parse] line \{t.line}:\{t.col}: \{msg}")
}

/// True when the current token is the given punctuation.
fn Parser::at(self : Parser, s : String) -> Bool {
  match self.cur_kind() {
    Punct(p) => p == s
    _ => false
  }
}

/// True when the current token is the given identifier/keyword.
fn Parser::at_kw(self : Parser, s : String) -> Bool {
  match self.cur_kind() {
    Ident(p) => p == s
    _ => false
  }
}

fn Parser::eat(self : Parser, s : String) -> Bool {
  if self.at(s) {
    self.advance()
    true
  } else {
    false
  }
}

fn Parser::eat_kw(self : Parser, s : String) -> Bool {
  if self.at_kw(s) {
    self.advance()
    true
  } else {
    false
  }
}

fn Parser::expect(self : Parser, s : String) -> Unit {
  if !self.eat(s) {
    self.error("expected '\{s}'")
  }
}

fn Parser::expect_ident(self : Parser) -> String {
  match self.cur_kind() {
    Ident(p) => {
      self.advance()
      p
    }
    _ => {
      self.error("expected identifier")
      "<error>"
    }
  }
}

fn Parser::at_eof(self : Parser) -> Bool {
  match self.cur_kind() {
    @lexer.Eof => true
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Expressions
// ---------------------------------------------------------------------------

fn Parser::parse_expr(self : Parser) -> @ast.Expr {
  self.parse_ternary()
}

fn Parser::parse_ternary(self : Parser) -> @ast.Expr {
  let cond = self.parse_lor()
  if self.eat("?") {
    let a = self.parse_ternary()
    self.expect(":")
    let b = self.parse_ternary()
    @ast.Cond(cond, a, b)
  } else {
    cond
  }
}

fn Parser::parse_lor(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_land()
  while self.at("||") {
    self.advance()
    let rhs = self.parse_land()
    lhs = @ast.Binary(@ast.LogOr, lhs, rhs)
  }
  lhs
}

fn Parser::parse_land(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_bor()
  while self.at("&&") {
    self.advance()
    let rhs = self.parse_bor()
    lhs = @ast.Binary(@ast.LogAnd, lhs, rhs)
  }
  lhs
}

fn Parser::parse_bor(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_bxor()
  while self.at("|") {
    self.advance()
    let rhs = self.parse_bxor()
    lhs = @ast.Binary(@ast.BitOr, lhs, rhs)
  }
  lhs
}

fn Parser::parse_bxor(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_band()
  while self.at("^") || self.at("~^") || self.at("^~") {
    let op = if self.at("^") { @ast.BitXor } else { @ast.BitXnor }
    self.advance()
    let rhs = self.parse_band()
    lhs = @ast.Binary(op, lhs, rhs)
  }
  lhs
}

fn Parser::parse_band(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_eq()
  while self.at("&") {
    self.advance()
    let rhs = self.parse_eq()
    lhs = @ast.Binary(@ast.BitAnd, lhs, rhs)
  }
  lhs
}

fn Parser::parse_eq(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_rel()
  let mut go = true
  while go {
    let op = if self.at("==") {
      Some(@ast.Eq)
    } else if self.at("!=") {
      Some(@ast.Ne)
    } else if self.at("===") {
      Some(@ast.CaseEq)
    } else if self.at("!==") {
      Some(@ast.CaseNe)
    } else {
      None
    }
    match op {
      Some(o) => {
        self.advance()
        let rhs = self.parse_rel()
        lhs = @ast.Binary(o, lhs, rhs)
      }
      None => go = false
    }
  }
  lhs
}

fn Parser::parse_rel(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_shift()
  let mut go = true
  while go {
    let op = if self.at("<=") {
      Some(@ast.Le)
    } else if self.at(">=") {
      Some(@ast.Ge)
    } else if self.at("<") {
      Some(@ast.Lt)
    } else if self.at(">") {
      Some(@ast.Gt)
    } else {
      None
    }
    match op {
      Some(o) => {
        self.advance()
        let rhs = self.parse_shift()
        lhs = @ast.Binary(o, lhs, rhs)
      }
      None => go = false
    }
  }
  lhs
}

fn Parser::parse_shift(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_add()
  let mut go = true
  while go {
    let op = if self.at("<<") {
      Some(@ast.Shl)
    } else if self.at(">>>") {
      Some(@ast.Ashr)
    } else if self.at(">>") {
      Some(@ast.Shr)
    } else {
      None
    }
    match op {
      Some(o) => {
        self.advance()
        let rhs = self.parse_add()
        lhs = @ast.Binary(o, lhs, rhs)
      }
      None => go = false
    }
  }
  lhs
}

fn Parser::parse_add(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_mul()
  let mut go = true
  while go {
    let op = if self.at("+") {
      Some(@ast.Add)
    } else if self.at("-") {
      Some(@ast.Sub)
    } else {
      None
    }
    match op {
      Some(o) => {
        self.advance()
        let rhs = self.parse_mul()
        lhs = @ast.Binary(o, lhs, rhs)
      }
      None => go = false
    }
  }
  lhs
}

fn Parser::parse_mul(self : Parser) -> @ast.Expr {
  let mut lhs = self.parse_unary()
  let mut go = true
  while go {
    let op = if self.at("*") {
      Some(@ast.Mul)
    } else if self.at("/") {
      Some(@ast.Div)
    } else if self.at("%") {
      Some(@ast.Mod)
    } else {
      None
    }
    match op {
      Some(o) => {
        self.advance()
        let rhs = self.parse_unary()
        lhs = @ast.Binary(o, lhs, rhs)
      }
      None => go = false
    }
  }
  lhs
}

fn Parser::parse_unary(self : Parser) -> @ast.Expr {
  let op = if self.at("~") {
    Some(@ast.BitNot)
  } else if self.at("!") {
    Some(@ast.Not)
  } else if self.at("~&") {
    Some(@ast.RedAnd)
  } else if self.at("~|") {
    Some(@ast.RedOr)
  } else if self.at("-") {
    Some(@ast.Minus)
  } else if self.at("+") {
    Some(@ast.Plus)
  } else if self.at("&") {
    Some(@ast.RedAnd)
  } else if self.at("|") {
    Some(@ast.RedOr)
  } else if self.at("^") {
    Some(@ast.RedXor)
  } else {
    None
  }
  match op {
    Some(o) => {
      self.advance()
      let operand = self.parse_unary()
      @ast.Unary(o, operand)
    }
    None => self.parse_power()
  }
}

fn Parser::parse_power(self : Parser) -> @ast.Expr {
  let lhs = self.parse_primary()
  if self.at("**") {
    self.advance()
    let rhs = self.parse_unary()
    @ast.Binary(@ast.Pow, lhs, rhs)
  } else {
    lhs
  }
}

fn Parser::parse_primary(self : Parser) -> @ast.Expr {
  match self.cur_kind() {
    Number(b) => {
      self.advance()
      @ast.Number({ bits: b })
    }
    Str(s) => {
      self.advance()
      @ast.Str(s)
    }
    Ident(name) => {
      self.advance()
      if self.at("(") {
        // Function or system task call used as an expression.
        self.advance()
        let args = self.parse_args()
        self.expect(")")
        @ast.Call(name, args)
      } else if self.at("[") {
        self.advance()
        let hi = self.parse_expr()
        if self.eat(":") {
          let lo = self.parse_expr()
          self.expect("]")
          @ast.PartSel(@ast.Ident(name), hi, lo)
        } else {
          self.expect("]")
          @ast.BitSel(@ast.Ident(name), hi)
        }
      } else {
        @ast.Ident(name)
      }
    }
    Punct(p) =>
      if p == "(" {
        self.advance()
        let e = self.parse_expr()
        self.expect(")")
        e
      } else if p == "{" {
        self.advance()
        self.parse_concat()
      } else {
        self.error("unexpected token in expression: '\{p}'")
        self.advance()
        @ast.Number({ bits: @value.Bits::zero(1) })
      }
    _ => {
      self.error("unexpected end of expression")
      self.advance()
      @ast.Number({ bits: @value.Bits::zero(1) })
    }
  }
}

fn Parser::parse_concat(self : Parser) -> @ast.Expr {
  // Already past '{'.  Either {a, b, c} or {N{a, b}}.
  let first = self.parse_expr()
  if self.at("{") {
    // replication
    self.advance()
    let items : Array[@ast.Expr] = []
    items.push(self.parse_expr())
    while self.eat(",") {
      items.push(self.parse_expr())
    }
    self.expect("}")
    self.expect("}")
    @ast.Repl(first, items)
  } else {
    let items : Array[@ast.Expr] = [first]
    while self.eat(",") {
      items.push(self.parse_expr())
    }
    self.expect("}")
    @ast.Concat(items)
  }
}

fn Parser::parse_args(self : Parser) -> Array[@ast.Expr] {
  let args : Array[@ast.Expr] = []
  if self.at(")") {
    return args
  }
  args.push(self.parse_expr())
  while self.eat(",") {
    args.push(self.parse_expr())
  }
  args
}

// ---------------------------------------------------------------------------
// Lvalues
// ---------------------------------------------------------------------------

fn Parser::parse_lvalue(self : Parser) -> @ast.LValue {
  let name = self.expect_ident()
  if self.eat("[") {
    let hi = self.parse_expr()
    if self.eat(":") {
      let lo = self.parse_expr()
      self.expect("]")
      { name: name, sel: @ast.Part(hi, lo) }
    } else {
      self.expect("]")
      { name: name, sel: @ast.Bit(hi) }
    }
  } else {
    { name: name, sel: @ast.Whole }
  }
}

// ---------------------------------------------------------------------------
// Statements
// ---------------------------------------------------------------------------

fn Parser::parse_stmt(self : Parser) -> @ast.Stmt {
  if self.eat(";") {
    return @ast.Null
  }
  if self.at_kw("begin") {
    self.advance()
    if self.eat(":") {
      self.expect_ident() |> ignore
    }
    let stmts : Array[@ast.Stmt] = []
    while !self.at_kw("end") && !self.at_eof() {
      stmts.push(self.parse_stmt())
    }
    self.eat_kw("end") |> ignore
    if self.eat(":") {
      self.expect_ident() |> ignore
    }
    return @ast.Block(stmts)
  }
  if self.eat_kw("if") {
    self.expect("(")
    let cond = self.parse_expr()
    self.expect(")")
    let then_ = self.parse_stmt()
    let else_ = if self.eat_kw("else") { Some(self.parse_stmt()) } else { None }
    return @ast.If(cond, then_, else_)
  }
  if self.eat_kw("case") {
    self.expect("(")
    let sel = self.parse_expr()
    self.expect(")")
    let arms : Array[@ast.CaseArm] = []
    while !self.at_kw("endcase") && !self.at_eof() {
      if self.eat_kw("default") {
        self.eat(":") |> ignore
        arms.push({ labels: None, body: self.parse_stmt() })
      } else {
        let labels : Array[@ast.Expr] = [self.parse_expr()]
        while self.eat(",") {
          labels.push(self.parse_expr())
        }
        self.eat(":") |> ignore
        arms.push({ labels: Some(labels), body: self.parse_stmt() })
      }
    }
    self.eat_kw("endcase") |> ignore
    return @ast.Case(sel, arms, None)
  }
  if self.eat_kw("for") {
    self.expect("(")
    let init = self.parse_assign_core()
    self.expect(";")
    let cond = self.parse_expr()
    self.expect(";")
    let step = self.parse_assign_core()
    self.expect(")")
    let body = self.parse_stmt()
    return @ast.For(init, cond, step, body)
  }
  if self.eat_kw("while") {
    self.expect("(")
    let cond = self.parse_expr()
    self.expect(")")
    let body = self.parse_stmt()
    return @ast.While(cond, body)
  }
  if self.eat_kw("repeat") {
    self.expect("(")
    let count = self.parse_expr()
    self.expect(")")
    let body = self.parse_stmt()
    return @ast.Repeat(count, body)
  }
  if self.eat_kw("disable") {
    let name = self.expect_ident()
    self.expect(";")
    return @ast.Disable(name)
  }
  if self.at("#") {
    self.advance()
    let d = self.parse_expr()
    let body = self.parse_stmt()
    return @ast.Delay(d, body)
  }
  if self.eat("@") {
    self.expect("(")
    let specs = self.parse_sens_list()
    self.expect(")")
    let body = self.parse_stmt()
    return @ast.EventCtrl(specs, body)
  }
  // Assignment or task call.
  match self.cur_kind() {
    Ident(name) =>
      if name == "$display" ||
        name == "$write" ||
        name == "$dumpfile" ||
        name == "$dumpvars" ||
        name == "$finish" ||
        name == "$stop" ||
        name.has_prefix("$monitor") ||
        name.has_prefix("$strobe") {
        self.advance()
        let mut args : Array[@ast.Expr] = []
        if self.eat("(") {
          args = self.parse_args()
          self.expect(")")
        }
        self.expect(";")
        return @ast.CallStmt(name, args)
      } else {
        // Could still be a user task call `foo(a);`.
        let save = self.pos
        self.advance()
        if self.at("(") {
          self.advance()
          let args = self.parse_args()
          self.expect(")")
          self.expect(";")
          return @ast.CallStmt(name, args)
        }
        self.pos = save
        return self.parse_assign_stmt()
      }
    _ => {
      self.error("expected statement")
      self.advance()
      @ast.Null
    }
  }
}

/// Assignment core: `lvalue = expr` / `lvalue <= expr`, no semicolon.
fn Parser::parse_assign_core(self : Parser) -> @ast.Stmt {
  let lv = self.parse_lvalue()
  if self.eat("<=") {
    let rhs = self.parse_expr()
    @ast.Assign(@ast.NonBlocking, lv, rhs)
  } else if self.eat("=") {
    let rhs = self.parse_expr()
    @ast.Assign(@ast.Blocking, lv, rhs)
  } else {
    self.error("expected '=' or '<=' in assignment")
    @ast.Null
  }
}

/// Assignment statement with the trailing semicolon.
fn Parser::parse_assign_stmt(self : Parser) -> @ast.Stmt {
  let lv = self.parse_lvalue()
  if self.eat("<=") {
    let rhs = self.parse_expr()
    self.expect(";")
    @ast.Assign(@ast.NonBlocking, lv, rhs)
  } else if self.eat("=") {
    let rhs = self.parse_expr()
    self.expect(";")
    @ast.Assign(@ast.Blocking, lv, rhs)
  } else {
    self.error("expected '=' or '<=' in assignment")
    @ast.Null
  }
}

fn Parser::parse_sens_list(self : Parser) -> Array[@ast.EventSpec] {
  let specs : Array[@ast.EventSpec] = []
  if self.eat("*") {
    return specs
  }
  if self.at(")") {
    return specs
  }
  let mut go = true
  while go {
    let edge = if self.eat_kw("posedge") {
      @ast.PosEdge
    } else if self.eat_kw("negedge") {
      @ast.NegEdge
    } else {
      @ast.Any
    }
    let e = self.parse_expr()
    specs.push({ edge: edge, expr: e })
    if self.eat(",") || self.eat_kw("or") {
      go = true
    } else {
      go = false
    }
  }
  specs
}

// ---------------------------------------------------------------------------
// Module items
// ---------------------------------------------------------------------------

fn Parser::parse_range(self : Parser) -> (@ast.Expr, @ast.Expr)? {
  if self.eat("[") {
    let hi = self.parse_expr()
    self.expect(":")
    let lo = self.parse_expr()
    self.expect("]")
    Some((hi, lo))
  } else {
    None
  }
}

fn Parser::parse_design(self : Parser) -> @ast.Design {
  let mods : Array[@ast.Module] = []
  while !self.at_eof() {
    if self.eat_kw("module") {
      mods.push(self.parse_module())
    } else if self.eat_kw("endmodule") {
      // stray
    } else if self.at(";") {
      self.advance()
    } else {
      self.error("expected 'module'")
      self.advance()
    }
  }
  { modules: mods }
}

fn Parser::parse_module(self : Parser) -> @ast.Module {
  let name = self.expect_ident()
  let ports : Array[@ast.Port] = []
  let port_decls : Array[@ast.Port] = []
  let header_params : Array[@ast.ParamDecl] = []
  if self.eat("#") {
    self.expect("(")
    while !self.at(")") && !self.at_eof() {
      self.eat_kw("parameter") |> ignore
      self.eat_kw("localparam") |> ignore
      let range = self.parse_range()
      let pname = self.expect_ident()
      let value = if self.eat("=") {
        self.parse_expr()
      } else {
        @ast.Number({ bits: @value.Bits::zero(1) })
      }
      header_params.push({ range: range, name: pname, value: value })
      if !self.eat(",") {
        break
      }
    }
    self.expect(")")
  }
  if self.eat("(") {
    if self.at_kw("input") || self.at_kw("output") || self.at_kw("inout") {
      port_decls.push(self.parse_port_decl())
      while self.eat(",") {
        port_decls.push(self.parse_port_decl())
      }
    } else {
      // Non-ANSI: just names; declarations appear in the body.
      while !self.at(")") && !self.at_eof() {
        let n = self.expect_ident()
        ports.push({ dir: @ast.Inout, range: None, names: [n] })
        if !self.eat(",") {
          break
        }
      }
    }
    self.expect(")")
  }
  self.expect(";")
  let params : Array[@ast.ParamDecl] = header_params
  let vars : Array[@ast.VarDecl] = []
  let assigns : Array[@ast.ContAssign] = []
  let processes : Array[@ast.Process] = []
  let instances : Array[@ast.Instance] = []
  let functions : Array[@ast.Function] = []
  let mut go = true
  while go {
    if self.at_kw("endmodule") || self.at_eof() {
      go = false
    } else if self.eat_kw("parameter") || self.eat_kw("localparam") {
      self.parse_params(params)
    } else if self.at_kw("input") || self.at_kw("output") || self.at_kw("inout") {
      port_decls.push(self.parse_body_port())
    } else if self.at_kw("wire") ||
      self.at_kw("reg") ||
      self.at_kw("integer") ||
      self.at_kw("logic") {
      vars.push(self.parse_var_decl())
    } else if self.eat_kw("assign") {
      self.parse_assigns(assigns)
    } else if self.at_kw("always") || self.at_kw("initial") {
      processes.push(self.parse_process())
    } else if self.eat_kw("function") {
      functions.push(self.parse_function())
    } else if self.at(";") {
      self.advance()
    } else {
      instances.push(self.parse_instance())
    }
  }
  if self.eat_kw("endmodule") {
    if self.eat(":") {
      self.expect_ident() |> ignore
    }
  }
  {
    name: name,
    params: params,
    ports: if port_decls.length() > 0 { port_decls } else { ports },
    vars: vars,
    assigns: assigns,
    processes: processes,
    instances: instances,
    functions: functions,
  }
}

fn Parser::parse_port_decl(self : Parser) -> @ast.Port {
  let dir = if self.eat_kw("input") {
    @ast.Input
  } else if self.eat_kw("output") {
    @ast.Output
  } else {
    self.eat_kw("inout") |> ignore
    @ast.Inout
  }
  self.eat_kw("reg") |> ignore
  self.eat_kw("wire") |> ignore
  let range = self.parse_range()
  let names : Array[String] = [self.expect_ident()]
  { dir: dir, range: range, names: names }
}

fn Parser::parse_body_port(self : Parser) -> @ast.Port {
  let dir = if self.eat_kw("input") {
    @ast.Input
  } else if self.eat_kw("output") {
    @ast.Output
  } else {
    self.eat_kw("inout") |> ignore
    @ast.Inout
  }
  self.eat_kw("reg") |> ignore
  self.eat_kw("wire") |> ignore
  let range = self.parse_range()
  if self.at_kw("reg") || self.at_kw("wire") {
    self.advance()
  }
  let names : Array[String] = []
  let mut go = true
  while go {
    names.push(self.expect_ident())
    if self.eat(",") {
      if self.at_kw("input") || self.at_kw("output") || self.at_kw("inout") {
        go = false
      }
    } else {
      go = false
    }
  }
  self.expect(";")
  { dir: dir, range: range, names: names }
}

fn Parser::parse_params(self : Parser, out : Array[@ast.ParamDecl]) -> Unit {
  let range = self.parse_range()
  let mut go = true
  while go {
    let name = self.expect_ident()
    let value = if self.eat("=") {
      self.parse_expr()
    } else {
      @ast.Number({ bits: @value.Bits::zero(1) })
    }
    out.push({ range: range, name: name, value: value })
    if !self.eat(",") {
      go = false
    }
  }
  self.expect(";")
}

fn Parser::parse_var_decl(self : Parser) -> @ast.VarDecl {
  let kind = if self.eat_kw("reg") {
    @ast.Reg
  } else if self.eat_kw("integer") {
    @ast.Integer
  } else if self.eat_kw("logic") {
    @ast.Logic
  } else {
    self.eat_kw("wire") |> ignore
    @ast.Wire
  }
  let range = self.parse_range()
  let names : Array[String] = []
  let inits : Array[@ast.Expr?] = []
  let mut go = true
  while go {
    names.push(self.expect_ident())
    if self.eat("=") {
      inits.push(Some(self.parse_expr()))
    } else {
      inits.push(None)
    }
    if !self.eat(",") {
      go = false
    }
  }
  self.expect(";")
  { kind: kind, range: range, names: names, init: inits[0] }
}

fn Parser::parse_assigns(self : Parser, out : Array[@ast.ContAssign]) -> Unit {
  let mut go = true
  while go {
    let lv = self.parse_lvalue()
    self.expect("=")
    let rhs = self.parse_expr()
    out.push({ lhs: lv, rhs: rhs })
    if !self.eat(",") {
      go = false
    }
  }
  self.expect(";")
}

fn Parser::parse_process(self : Parser) -> @ast.Process {
  if self.eat_kw("initial") {
    return { kind: @ast.Initial, body: self.parse_stmt() }
  }
  self.eat_kw("always") |> ignore
  if self.eat("@") {
    if self.eat("(") {
      let specs = self.parse_sens_list()
      self.expect(")")
      return {
        kind: @ast.Always(specs),
        body: self.parse_stmt(),
      }
    } else if self.eat("*") {
      return { kind: @ast.AlwaysComb, body: self.parse_stmt() }
    } else {
      let specs : Array[@ast.EventSpec] = []
      return { kind: @ast.Always(specs), body: self.parse_stmt() }
    }
  }
  { kind: @ast.AlwaysComb, body: self.parse_stmt() }
}

fn Parser::parse_function(self : Parser) -> @ast.Function {
  let range = self.parse_range()
  let name = self.expect_ident()
  self.expect("(")
  let inputs : Array[@ast.VarDecl] = []
  while !self.at(")") && !self.at_eof() {
    self.eat_kw("input") |> ignore
    let r = self.parse_range()
    let n = self.expect_ident()
    inputs.push({ kind: @ast.Wire, range: r, names: [n], init: None })
    if !self.eat(",") {
      break
    }
  }
  self.expect(")")
  self.expect(";")
  let stmts : Array[@ast.Stmt] = []
  while !self.at_kw("endfunction") && !self.at_eof() {
    stmts.push(self.parse_stmt())
  }
  self.eat_kw("endfunction") |> ignore
  {
    name: name,
    ret_range: range,
    inputs: inputs,
    body: @ast.Block(stmts),
  }
}

fn Parser::parse_instance(self : Parser) -> @ast.Instance {
  let module_name = self.expect_ident()
  let params : Array[(String?, @ast.Expr)] = []
  if self.eat("#") {
    self.expect("(")
    while !self.at(")") && !self.at_eof() {
      if self.eat(".") {
        let n = self.expect_ident()
        self.expect("(")
        let e = self.parse_expr()
        self.expect(")")
        params.push((Some(n), e))
      } else {
        params.push((None, self.parse_expr()))
      }
      if !self.eat(",") {
        break
      }
    }
    self.expect(")")
  }
  let mut instance_name = ""
  if !self.at("(") && !self.at(";") {
    instance_name = self.expect_ident()
  }
  let conns : Array[@ast.PortConn] = []
  if self.eat("(") {
    while !self.at(")") && !self.at_eof() {
      if self.eat(".") {
        let n = self.expect_ident()
        self.expect("(")
        let e = if self.at(")") { None } else { Some(self.parse_expr()) }
        self.expect(")")
        conns.push({ name: Some(n), expr: e })
      } else {
        conns.push({ name: None, expr: Some(self.parse_expr()) })
      }
      if !self.eat(",") {
        break
      }
    }
    self.expect(")")
  }
  self.expect(";")
  {
    module_name: module_name,
    instance_name: instance_name,
    params: params,
    ports: conns,
  }
}

/// Parse a whole source file.
pub fn parse(src : String) -> (@ast.Design, Array[String]) {
  let (toks, lex_errs) = @lexer.tokenize(src)
  let p = Parser::new(toks)
  let d = p.parse_design()
  (d, lex_errs + p.errors)
}
