// Elaboration tests: hierarchy flattening, parameter propagation, ports.

///|
fn widths(n : Netlist) -> Array[Int32] {
  let out : Array[Int32] = []
  for s in n.sigs {
    out.push(s.width)
  }
  out
}

///|
test "elaborates a single module" {
  let src = "module top(input [7:0] a, input [7:0] b, output [8:0] s);\n" +
    "  wire [7:0] t;\n" +
    "  assign t = a & b;\n" +
    "  assign s = {1'b0, t};\n" +
    "endmodule\n"
  let (d, _) = @parser.parse(src)
  let n = elaborate(d)
  inspect(n.errors.length(), content="0")
  inspect(n.sigs.length(), content="4")
  inspect(n.sigs[0].name, content="a")
  inspect(n.sigs[2].width, content="9")
  inspect(n.assigns.length(), content="2")
  inspect(n.procs.length(), content="0")
}

///|
test "flattens an instance and connects its ports" {
  let src = "module add #(parameter W = 8)(input [W-1:0] a, input [W-1:0] b, output [W-1:0] s);\n" +
    "  assign s = a + b;\n" +
    "endmodule\n" +
    "module top(input [7:0] x, input [7:0] y, output [7:0] z);\n" +
    "  wire [7:0] t;\n" +
    "  add #(.W(8)) u (.a(x), .b(y), .s(t));\n" +
    "  assign z = t;\n" +
    "endmodule\n"
  let (d, _) = @parser.parse(src)
  let n = elaborate_top(d, "top")
  inspect(n.errors.length(), content="0")
  // top: x y z t; child: u.a u.b u.s
  inspect(n.sigs.length(), content="7")
  inspect(n.sigs[4].name, content="u.a")
  inspect(n.sigs[4].width, content="8")
  // 1 top assign + 1 child assign + 3 port binds
  inspect(n.assigns.length(), content="5")
  inspect(n.scopes.length(), content="2")
}

///|
test "parameter override changes child widths" {
  let src = "module inv #(parameter W = 4)(input [W-1:0] a, output [W-1:0] y);\n" +
    "  assign y = ~a;\n" +
    "endmodule\n" +
    "module top(input [15:0] a16, output [15:0] y16);\n" +
    "  inv #(.W(16)) u (.a(a16), .y(y16));\n" +
    "endmodule\n"
  let (d, _) = @parser.parse(src)
  let n = elaborate_top(d, "top")
  inspect(n.errors.length(), content="0")
  let mut child_width = 0
  for s in n.sigs {
    if s.name == "u.a" {
      child_width = s.width
    }
  }
  inspect(child_width, content="16")
}

///|
test "reports an unknown module" {
  let src = "module top(input a, output y);\n" +
    "  missing u (.a(a), .y(y));\n" +
    "endmodule\n"
  let (d, _) = @parser.parse(src)
  let n = elaborate_top(d, "top")
  inspect(n.errors.length(), content="1")
}

///|
test "negative ranges keep their width" {
  let src = "module top(input [3:0] a);\n  wire [0:7] b;\n  assign b = a;\nendmodule\n"
  let (d, _) = @parser.parse(src)
  let n = elaborate(d)
  inspect(widths(n).length(), content="2")
  inspect(n.sigs[1].width, content="8")
}
