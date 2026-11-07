// Event-driven engine: process lowering, delta cycles, statement execution and
// the $display formatter.
//
// A process body is *lowered* into a linear list of `Op`s whose only waits are
// `WaitDelay` / `WaitEdges`.  "Run until you block" then becomes a tiny
// interpreter loop, and all delta-cycle bookkeeping lives in one place.

pub(all) enum Op {
  Run(@ast.Stmt)
  WaitDelay(@ast.Expr)
  /// Resolved signals and their edge modes (0 = any, 1 = posedge, 2 = negedge).
  WaitEdges(Array[Int32], Array[Int32])
  Finish
  Jump(Int32)
}

pub(all) struct Thread {
  scope : Int32
  ops : Array[Op]
  mut pc : Int32
  /// 0 = ready, 1 = waiting on time, 2 = waiting on edges, 3 = done.
  mut waiting : Int32
  mut wait_time : Int64
  mut edge_sigs : Array[Int32]
  mut edge_modes : Array[Int32]
}

/// A combinational process re-run by the settle loop until nothing moves.
pub(all) struct Comb {
  scope : Int32
  body : @ast.Stmt
}

pub(all) struct Lowered {
  threads : Array[Thread]
  combs : Array[Comb]
}

fn edge_mode(e : @ast.EventEdge) -> Int32 {
  match e {
    @ast.Any => 0
    @ast.PosEdge => 1
    @ast.NegEdge => 2
  }
}

fn resolve_specs(
  net : @elaborate.Netlist,
  scope : Int32,
  specs : Array[@ast.EventSpec],
) -> (Array[Int32], Array[Int32]) {
  let sigs : Array[Int32] = []
  let modes : Array[Int32] = []
  for sp in specs {
    match sp.expr {
      @ast.Ident(n) =>
        match net_lookup(net, scope, n) {
          Some(id) => {
            sigs.push(id)
            modes.push(edge_mode(sp.edge))
          }
          None => ()
        }
      _ => ()
    }
  }
  (sigs, modes)
}

/// Lower a statement; returns whether any wait op was emitted.
fn lower_stmt(net : @elaborate.Netlist, scope : Int32, s : @ast.Stmt, ops : Array[Op]) -> Bool {
  match s {
    @ast.Null => false
    @ast.Block(items) => {
      let mut w = false
      for it in items {
        if lower_stmt(net, scope, it, ops) {
          w = true
        }
      }
      w
    }
    @ast.Delay(e, body) => {
      ops.push(WaitDelay(e))
      let _ = lower_stmt(net, scope, body, ops)
      true
    }
    @ast.EventCtrl(specs, body) => {
      let r = resolve_specs(net, scope, specs)
      ops.push(WaitEdges(r.0, r.1))
      let _ = lower_stmt(net, scope, body, ops)
      true
    }
    @ast.Repeat(count, body) => {
      // Unroll a constant, small repeat that contains exactly one wait; any
      // other shape stays a `Run` so the engine never silently loses a wait.
      let tmp : Array[Op] = []
      let has_wait = lower_stmt(net, scope, body, tmp)
      let mut waits = 0
      for op in tmp {
        match op {
          WaitDelay(_) | WaitEdges(_) => waits = waits + 1
          _ => ()
        }
      }
      let n = match count {
        @ast.Number(l) => l.bits.to_int()
        _ => -1
      }
      if has_wait && waits == 1 && n >= 0 && n <= 64 {
        let mut i = 0
        while i < n {
          for op in tmp {
            ops.push(op)
          }
          i = i + 1
        }
        true
      } else {
        ops.push(Run(s))
        false
      }
    }
    _ => {
      ops.push(Run(s))
      false
    }
  }
}

/// Lower every process of the netlist into threads plus the combinational
/// processes that the settle loop must re-run.
pub fn lower_all(net : @elaborate.Netlist) -> Lowered {
  let threads : Array[Thread] = []
  let combs : Array[Comb] = []
  for p in net.procs {
    let ops : Array[Op] = []
    // `always` processes repeat forever; `initial` runs once.
    let mut loops = true
    let mut head_wait = false
    match p.kind {
      @ast.Initial => loops = false
      @ast.Always(specs) =>
        if specs.length() > 0 {
          let r = resolve_specs(net, p.scope, specs)
          ops.push(WaitEdges(r.0, r.1))
          head_wait = true
        }
      _ => ()
    }
    let body_wait = lower_stmt(net, p.scope, p.body, ops)
    let has_wait = head_wait || body_wait
    if loops && has_wait {
      ops.push(Jump(0))
    }
    // An `always` block that never waits is combinational: re-run it in the
    // settle loop instead of scheduling it as a thread.
    let is_comb = match p.kind {
      @ast.Initial => false
      _ => if has_wait { false } else { true }
    }
    if is_comb {
      combs.push({ scope: p.scope, body: p.body })
    } else {
      threads.push({
        scope: p.scope,
        ops: ops,
        pc: 0,
        waiting: 0,
        wait_time: 0L,
        edge_sigs: [],
        edge_modes: [],
      })
    }
  }
  { threads: threads, combs: combs }
}
