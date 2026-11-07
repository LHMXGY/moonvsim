// Abstract syntax tree for the Verilog-2001 synthesizable subset.

/// Source position, 1-based.
pub struct Pos {
  line : Int32
  col : Int32
}

/// A resolved numeric literal: width plus four-state value.
pub struct Lit {
  bits : @value.Bits
}

/// Unary operators.
pub enum UnOp {
  Plus
  Minus
  Not // !
  BitNot // ~
  RedAnd
  RedOr
  RedXor
}

/// Binary operators, in Verilog spelling for diagnostics.
pub enum BinOp {
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
pub enum Expr {
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
pub struct LValue {
  name : String
  sel : Sel
}

/// Sub-selection of an lvalue.
pub enum Sel {
  Whole
  Bit(Expr)
  Part(Expr, Expr)
}

/// Assignment flavour.
pub enum AssignKind {
  Blocking
  NonBlocking
}

/// Sensitivity / control events.
pub enum EventEdge {
  Any
  PosEdge
  NegEdge
}

/// One entry in a sensitivity list.
pub struct EventSpec {
  edge : EventEdge
  expr : Expr
}

/// Statements.
pub enum Stmt {
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
pub struct CaseArm {
  labels : Array[Expr]? // None = default
  body : Stmt
}

/// Port direction.
pub enum Dir {
  Input
  Output
  Inout
}

/// Port declaration inside the module header or body.
pub struct Port {
  dir : Dir
  /// Declared range, `None` for a 1-bit port.
  range : (Expr, Expr)?
  names : Array[String]
}

/// `wire`/`reg`/`integer` declaration.
pub enum VarKind {
  Wire
  Reg
  Integer
  Logic
}

pub struct VarDecl {
  kind : VarKind
  range : (Expr, Expr)?
  names : Array[String]
  init : Expr?
}

/// `parameter NAME = expr;`
pub struct ParamDecl {
  range : (Expr, Expr)?
  name : String
  value : Expr
}

/// Continuous assignment.
pub struct ContAssign {
  lhs : LValue
  rhs : Expr
}

/// A named port connection on an instance.
pub struct PortConn {
  name : String?
  expr : Expr?
}

/// Module instantiation.
pub struct Instance {
  module_name : String
  instance_name : String
  params : Array[(String?, Expr)]
  ports : Array[PortConn]
}

/// `always` / `initial` process.
pub enum ProcessKind {
  Always(Array[EventSpec])
  AlwaysComb
  Initial
}

pub struct Process {
  kind : ProcessKind
  body : Stmt
}

/// A user function.
pub struct Function {
  name : String
  ret_range : (Expr, Expr)?
  inputs : Array[VarDecl]
  body : Stmt
}

/// A complete module.
pub struct Module {
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
pub struct Design {
  modules : Array[Module]
}
