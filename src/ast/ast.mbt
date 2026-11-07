// Abstract syntax tree for the Verilog-2001 synthesizable subset.

/// Source position, 1-based.
pub(all) struct Pos {
  line : Int32
  col : Int32
}

/// A resolved numeric literal: width plus four-state value.
pub(all) struct Lit {
  bits : @value.Bits
}

/// Unary operators.
pub(all) enum UnOp {
  Plus
  Minus
  Not // !
  BitNot // ~
  RedAnd
  RedOr
  RedXor
}

/// Binary operators, in Verilog spelling for diagnostics.
pub(all) enum BinOp {
  Add // +
  Sub // -
  Mul // *
  Div // /
  Mod // %
  Pow // **
  BitAnd // &
  BitOr // |
  BitXor // ^
  BitXnor // ^~
  LogAnd // &&
  LogOr // ||
  Lt // <
  Le // <=
  Gt // >
  Ge // >=
  Eq // ==
  Ne // !=
  CaseEq // ===
  CaseNe // !==
  Shl // <<
  Shr // >>
  Ashr // >>>
}

/// Expressions.
pub(all) enum Expr {
  Number(Lit)
  Ident(String)
  /// `name[index]`
  BitSel(Expr, Expr)
  /// `name[msb:lsb]`
  PartSel(Expr, Expr, Expr)
  Unary(UnOp, Expr)
  Binary(BinOp, Expr, Expr)
  Cond(Expr, Expr, Expr)
  Concat(Array[Expr])
  /// `{count{elems}}`
  Repl(Expr, Array[Expr])
  /// System or user function call, e.g. `$signed(a)`, `$clog2(N)`.
  Call(String, Array[Expr])
  /// String literal used as an argument, e.g. `$display("x=%d", x)`.
  Str(String)
}

/// An assignable target.
pub(all) struct LValue {
  name : String
  sel : Sel
}

/// Sub-selection of an lvalue.
pub(all) enum Sel {
  Whole
  Bit(Expr)
  Part(Expr, Expr)
}

/// Assignment flavour.
pub(all) enum AssignKind {
  Blocking
  NonBlocking
}

/// Sensitivity / control events.
pub(all) enum EventEdge {
  Any
  PosEdge
  NegEdge
}

/// One entry in a sensitivity list.
pub(all) struct EventSpec {
  edge : EventEdge
  expr : Expr
}

/// Statements.
pub(all) enum Stmt {
  Null
  Block(Array[Stmt])
  /// `lhs = rhs;` / `lhs <= rhs;`
  Assign(AssignKind, LValue, Expr)
  If(Expr, Stmt, Stmt?)
  Case(Expr, Array[CaseArm], Stmt?)
  For(Stmt, Expr, Stmt, Stmt)
  While(Expr, Stmt)
  Repeat(Expr, Stmt)
  /// `#10 stmt` or `#(expr) stmt`
  Delay(Expr, Stmt)
  /// `@(posedge clk) stmt`
  EventCtrl(Array[EventSpec], Stmt)
  /// System task or user task call statement (`$display(...)`, `$finish;`).
  CallStmt(String, Array[Expr])
  /// `disable foo;`
  Disable(String)
}

/// One arm of a case statement.  `None` means `default`.
pub(all) struct CaseArm {
  labels : Array[Expr]? // None = default
  body : Stmt
}

/// Port direction.
pub(all) enum Dir {
  Input
  Output
  Inout
}

/// Port declaration inside the module header or body.
pub(all) struct Port {
  dir : Dir
  /// Declared range, `None` for a 1-bit port.
  range : (Expr, Expr)?
  names : Array[String]
  /// `input signed [7:0] a`
  signed : Bool
}

/// `wire`/`reg`/`integer` declaration.
pub(all) enum VarKind {
  Wire
  Reg
  Integer
  Logic
}

pub(all) struct VarDecl {
  kind : VarKind
  range : (Expr, Expr)?
  names : Array[String]
  init : Expr?
  signed : Bool
}

/// `parameter NAME = expr;`
pub(all) struct ParamDecl {
  range : (Expr, Expr)?
  name : String
  value : Expr
  signed : Bool
}

/// Continuous assignment.
pub(all) struct ContAssign {
  lhs : LValue
  rhs : Expr
}

/// A named port connection on an instance.
pub(all) struct PortConn {
  name : String?
  expr : Expr?
}

/// Module instantiation.
pub(all) struct Instance {
  module_name : String
  instance_name : String
  params : Array[(String?, Expr)]
  ports : Array[PortConn]
}

/// `always` / `initial` process.
pub(all) enum ProcessKind {
  Always(Array[EventSpec])
  AlwaysComb
  Initial
}

pub(all) struct Process {
  kind : ProcessKind
  body : Stmt
}

/// A user function.
pub(all) struct Function {
  name : String
  ret_range : (Expr, Expr)?
  inputs : Array[VarDecl]
  body : Stmt
}

/// A complete module.
pub(all) struct Module {
  name : String
  params : Array[ParamDecl]
  ports : Array[Port]
  vars : Array[VarDecl]
  assigns : Array[ContAssign]
  processes : Array[Process]
  instances : Array[Instance]
  functions : Array[Function]
}

/// A parsed source file.
pub(all) struct Design {
  modules : Array[Module]
}
