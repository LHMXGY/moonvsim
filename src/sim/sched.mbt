// Scheduling: delta cycles, edge detection, time advance and statement
// execution.  This is the only place that mutates `Sim.time`/`Sim.finished`.

fn Sim::lvalue_width(self : Sim, scope : Int32, lv : @ast.LValue) -> Int32 {
  let w = match self.lookup(scope, lv.name) {
    Some(id) => self.sig_width(id)
    None => 1
  }
  match lv.sel {
    @ast.Whole => w
    @ast.Bit(_) => 1
    @ast.Part(hi, lo) => {
      let h = self.eval_int(scope, hi)
      let l = self.eval_int(scope, lo)
      let d = if h >= l { h - l } else { l - h }
      d + 1
    }
  }
}

/// Execute one statement (blocking semantics); non-blocking updates are queued.
fn Sim::exec(self : Sim, scope : Int32, s : @ast.Stmt) -> Unit {
  match s {
    @ast.Null => ()
    @ast.Block(items) =>
      for it in items {
        self.exec(scope, it)
      }
    @ast.Assign(kind, lv, e) => {
      let w = self.lvalue_width(scope, lv)
      let v = self.eval_sized(scope, e, w)
      match kind {
        @ast.Blocking => {
          let _ = self.write_lvalue(scope, lv, v)
        }
        @ast.NonBlocking =>
          match self.lookup(scope, lv.name) {
            Some(id) =>
              match lv.sel {
                @ast.Whole => self.write_nba(id, v)
                _ => {
                  let _ = self.write_lvalue(scope, lv, v)
                }
              }
            None => ()
          }
      }
    }
    @ast.If(c, t, e) => {
      let cv = self.eval(scope, c, 1).truth()
      let taken = match cv {
        Some(true) => true
        _ => false
      }
      if taken {
        self.exec(scope, t)
      } else {
        match e {
          Some(x) => self.exec(scope, x)
          None => ()
        }
      }
    }
    @ast.Case(sel, arms, default) => {
      let sv = self.eval(scope, sel, self.width_of(scope, sel))
      let mut done = false
      let mut default_body : @ast.Stmt? = None
      for arm in arms {
        match arm.labels {
          Some(labels) => {
            if !done {
              for lab in labels {
                if !done {
                  let lv = self.eval(scope, lab, sv.width)
                  let hit = match sv.bcase_eq(lv).truth() {
                    Some(true) => true
                    _ => false
                  }
                  if hit {
                    done = true
                    self.exec(scope, arm.body)
                  }
                }
              }
            }
          }
          None => default_body = Some(arm.body)
        }
      }
      if !done {
        match default_body {
          Some(d) => self.exec(scope, d)
          None =>
            match default {
              Some(d) => self.exec(scope, d)
              None => ()
            }
        }
      }
    }
    @ast.For(init, cond, step, body) => {
      self.exec(scope, init)
      let mut ticks = 0
      let mut go = true
      while go && ticks < 1000000 {
        ticks = ticks + 1
        let cv = self.eval(scope, cond, 1).truth()
        match cv {
          Some(true) => {
            self.exec(scope, body)
            self.exec(scope, step)
          }
          _ => go = false
        }
      }
    }
    @ast.While(cond, body) => {
      let mut ticks = 0
      let mut go = true
      while go && ticks < 1000000 {
        ticks = ticks + 1
        let cv = self.eval(scope, cond, 1).truth()
        match cv {
          Some(true) => self.exec(scope, body)
          _ => go = false
        }
      }
    }
    @ast.Repeat(count, body) => {
      let n = self.eval_int(scope, count)
      let mut i = 0
      while i < n {
        self.exec(scope, body)
        i = i + 1
      }
    }
    @ast.Delay(_, body) => {
      // Reached only if a delay survived lowering (inside an unlowerable
      // statement); advance nothing and keep the body running.
      self.log("[sim] delay inside an unsupported statement was ignored")
      self.exec(scope, body)
    }
    @ast.EventCtrl(_, body) => {
      self.log("[sim] event control inside an unsupported statement was ignored")
      self.exec(scope, body)
    }
    @ast.CallStmt(name, args) => self.exec_call(scope, name, args)
    @ast.Disable(_) => ()
  }
}

fn Sim::exec_call(self : Sim, scope : Int32, name : String, args : Array[@ast.Expr]) -> Unit {
  match name {
    "$display" => self.log(self.format_display(scope, args))
    "$write" => self.log(self.format_display(scope, args))
    "$finish" | "$stop" => self.finished = true
    _ => ()
  }
}

/// `$display`-style formatting: `%d %h %x %b %o %c %s %t %%`.
fn Sim::format_display(self : Sim, scope : Int32, args : Array[@ast.Expr]) -> String {
  if args.length() == 0 {
    return ""
  }
  let sb = StringBuilder()
  match args[0] {
    @ast.Str(fmt) => {
      let mut i = 0
      let mut ai = 1
      while i < fmt.length() {
        let ch = match fmt.get_char(i) {
          Some(c) => c
          None => ' '
        }
        if ch == '%' {
          i = i + 1
          let spec = match fmt.get_char(i) {
            Some(c) => c
            None => '?'
          }
          if spec == '%' {
            sb.write_char('%')
            i = i + 1
          } else {
            let mut width = 0
            let mut has_width = false
            while i < fmt.length() {
              let d = match fmt.get_char(i) {
                Some(c) => c
                None => ' '
              }
              if d >= '0' && d <= '9' {
                width = width * 10 + (d.to_int() - '0'.to_int())
                has_width = true
                i = i + 1
              } else {
                break
              }
            }
            let real_spec = match fmt.get_char(i) {
              Some(c) => c
              None => '?'
            }
            i = i + 1
            if ai < args.length() {
              let a = args[ai]
              ai = ai + 1
              let w = if has_width {
                width
              } else {
                self.width_of(scope, a)
              }
              let v = self.eval(scope, a, w)
              let out = if real_spec == 't' {
                self.time.to_string()
              } else {
                let raw = v.format(real_spec, if has_width { width } else { 0 }, false)
                if has_width {
                  raw
                } else {
                  raw
                }
              }
              sb.write_string(out)
            } else {
              sb.write_char(real_spec)
            }
          }
        } else {
          sb.write_char(ch)
          i = i + 1
        }
      }
    }
    _ => {
      let mut ai = 0
      for a in args {
        if ai > 0 {
          sb.write_char(' ')
        }
        let w = self.width_of(scope, a)
        sb.write_string(self.eval(scope, a, w).to_dec_string())
        ai = ai + 1
      }
    }
  }
  sb.to_string()
}

fn Sim::edge_hit(self : Sim, tid : Int32) -> Bool {
  let n = self.threads[tid].edge_sigs.length()
  let mut i = 0
  let mut hit = false
  while i < n {
    let id = self.threads[tid].edge_sigs[i]
    let mode = self.threads[tid].edge_modes[i]
    let old = self.prev[id].bit_at(0)
    let cur = self.vals[id].bit_at(0)
    let rose = old.to_char() != '1' && cur.to_char() == '1'
    let fell = old.to_char() != '0' && cur.to_char() == '0'
    let any = old.to_char() != cur.to_char()
    if (mode == 0 && any) || (mode == 1 && rose) || (mode == 2 && fell) {
      hit = true
    }
    i = i + 1
  }
  hit
}

fn Sim::run_thread(self : Sim, tid : Int32) -> Unit {
  let mut steps = 0
  let mut running = true
  while running && steps < 1000000 {
    steps = steps + 1
    let pc = self.threads[tid].pc
    let n = self.threads[tid].ops.length()
    if pc < 0 || pc >= n {
      self.threads[tid].waiting = 3
      running = false
    } else {
      let op = self.threads[tid].ops[pc]
      match op {
        Run(s) => {
          self.exec(self.threads[tid].scope, s)
          self.threads[tid].pc = pc + 1
        }
        Jump(t) => self.threads[tid].pc = t
        WaitDelay(e) => {
          let d = self.eval_int(self.threads[tid].scope, e)
          self.threads[tid].waiting = 1
          self.threads[tid].wait_time = self.time + d.to_int64()
          self.threads[tid].pc = pc + 1
          running = false
        }
        WaitEdges(sigs, modes) => {
          self.threads[tid].edge_sigs = sigs
          self.threads[tid].edge_modes = modes
          self.threads[tid].waiting = 2
          self.threads[tid].pc = pc + 1
          running = false
        }
        Finish => {
          self.finished = true
          self.threads[tid].waiting = 3
          running = false
        }
      }
    }
  }
}

/// Re-evaluate continuous assignments and combinational processes until the
/// design stops changing (or the delta budget is exhausted).
fn Sim::settle(self : Sim) -> Unit {
  let mut iter = 0
  self.dirty = true
  while self.dirty && iter < self.max_delta {
    self.dirty = false
    iter = iter + 1
    let mut i = 0
    for a in self.net.assigns {
      let sc = self.net.assign_scope[i]
      i = i + 1
      let w = self.lvalue_width(sc, a.lhs)
      let v = self.eval_sized(sc, a.rhs, w)
      let _ = self.write_lvalue(sc, a.lhs, v)
    }
    let mut j = 0
    while j < self.combs.length() {
      let c = self.combs[j]
      self.exec(c.scope, c.body)
      j = j + 1
    }
  }
}

/// Wake everything that is due now, then settle and propagate edges.
pub fn Sim::step_once(self : Sim) -> Unit {
  let mut round = 0
  let mut more = true
  while more && round < 1000 {
    round = round + 1
    self.snapshot()
    let mut i = 0
    while i < self.threads.length() {
      if self.threads[i].waiting == 0 {
        self.run_thread(i)
      }
      i = i + 1
    }
    let _ = self.commit_nba()
    self.settle()
    self.trace()
    let mut woke = false
    let mut j = 0
    while j < self.threads.length() {
      if self.threads[j].waiting == 2 && self.edge_hit(j) {
        self.threads[j].waiting = 0
        woke = true
      }
      j = j + 1
    }
    more = woke
    if self.finished {
      more = false
    }
  }
}

fn Sim::next_time(self : Sim) -> Int64 {
  let mut best = -1L
  let mut i = 0
  while i < self.threads.length() {
    if self.threads[i].waiting == 1 {
      let t = self.threads[i].wait_time
      if best < 0L || t < best {
        best = t
      }
    }
    i = i + 1
  }
  best
}

/// Run until `$finish`, until no time-based events remain, or until `max_time`.
pub fn Sim::run(self : Sim, max_time : Int64) -> Unit {
  self.step_once()
  let mut ticks = 0
  while !self.finished && ticks < 10000000 {
    ticks = ticks + 1
    let nt = self.next_time()
    if nt < 0L || nt > max_time {
      break
    }
    self.time = nt
    let mut i = 0
    while i < self.threads.length() {
      if self.threads[i].waiting == 1 && self.threads[i].wait_time <= nt {
        self.threads[i].waiting = 0
      }
      i = i + 1
    }
    self.step_once()
  }
  if self.time < max_time && !self.finished {
    self.time = max_time
  }
}
