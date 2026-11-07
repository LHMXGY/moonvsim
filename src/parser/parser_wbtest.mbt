// Parser tests: each source snippet exercises one syntactic feature.

test "parse ansi port module" {
  let src =
    "module top(input clk, input rst, output reg [3:0] q);\n" +
    "  always @(posedge clk or negedge rst) begin\n" +
    "    if (!rst) q <= 4'd0;\n" +
    "    else q <= q + 1'b1;\n" +
    "  end\n" +
    "endmodule\n"
  let (d, errs) = parse(src)
  inspect(errs.length(), content="0")
  inspect(d.modules.length(), content="1")
  let m = d.modules[0]
  inspect(m.name, content="top")
  inspect(m.ports.length(), content="3")
  inspect(m.processes.length(), content="1")
  match m.processes[0].kind {
    @ast.Always(sens) => inspect(sens.length(), content="2")
    _ => inspect("not-always", content="always")
  }
}

test "parse non-ansi ports and continuous assigns" {
  let src =
    "module and2(a, b, y);\n" +
    "  input a;\n" +
    "  input b;\n" +
    "  output y;\n" +
    "  assign y = a & b;\n" +
    "endmodule\n"
  let (d, errs) = parse(src)
  inspect(errs.length(), content="0")
  let m = d.modules[0]
  inspect(m.ports.length(), content="3")
  inspect(m.assigns.length(), content="1")
}

test "parse case, for and repeat statements" {
  let src =
    "module m(input [1:0] s, output reg [3:0] y);\n" +
    "  integer i;\n" +
    "  always @(*) begin\n" +
    "    case (s)\n" +
    "      2'd0: y = 4'd1;\n" +
    "      2'd1, 2'd2: y = 4'd2;\n" +
    "      default: y = 4'd0;\n" +
    "    endcase\n" +
    "    for (i = 0; i < 4; i = i + 1) y = y + 1;\n" +
    "    repeat (2) y = y << 1;\n" +
    "  end\n" +
    "endmodule\n"
  let (d, errs) = parse(src)
  inspect(errs.length(), content="0")
  match d.modules[0].processes[0].kind {
    @ast.Always(sens) => inspect(sens.length(), content="0")
    _ => inspect("not-always", content="always")
  }
  match d.modules[0].processes[0].body {
    @ast.Block(stmts) => inspect(stmts.length(), content="3")
    _ => inspect("not-block", content="block")
  }
}

test "parse function and instance with parameter override" {
  let src =
    "module add #(parameter W = 8) (input [W-1:0] a, input [W-1:0] b, output [W-1:0] s);\n" +
    "  assign s = a + b;\n" +
    "endmodule\n" +
    "module top(input [7:0] x, input [7:0] y, output [7:0] z);\n" +
    "  add #(.W(8)) u_add (.a(x), .b(y), .s(z));\n" +
    "endmodule\n"
  let (d, errs) = parse(src)
  inspect(errs.length(), content="0")
  inspect(d.modules.length(), content="2")
  inspect(d.modules[0].params.length(), content="1")
  let top = d.modules[1]
  inspect(top.instances.length(), content="1")
  inspect(top.instances[0].module_name, content="add")
  inspect(top.instances[0].instance_name, content="u_add")
  inspect(top.instances[0].ports.length(), content="3")
}

test "parse expressions with precedence and concat" {
  let src =
    "module m;\n" +
    "  wire [7:0] a;\n" +
    "  assign a = {4'hf, 4'b0000} & 8'h0f | 8'h10;\n" +
    "endmodule\n"
  let (d, errs) = parse(src)
  inspect(errs.length(), content="0")
  match d.modules[0].assigns[0].rhs {
    @ast.Binary(@ast.BitOr, _, _) => inspect("or-root", content="or-root")
    _ => inspect("other", content="or-root")
  }
}

test "reports a syntax error instead of looping" {
  let src = "module broken(input a)\n  assign a = ;\nendmodule\n"
  let (_, errs) = parse(src)
  inspect(errs.length() > 0, content="true")
}
