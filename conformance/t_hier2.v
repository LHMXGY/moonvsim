// Two instances of the same parameterised module with different widths.
module add_w #(
  parameter W = 4
) (
  input  [W-1:0] a,
  input  [W-1:0] b,
  output [W:0]   s
);
  assign s = a + b;
endmodule

module t_hier2;
  reg  [3:0] a4;
  reg  [3:0] b4;
  wire [4:0] s4;
  reg  [7:0] a8;
  reg  [7:0] b8;
  wire [8:0] s8;

  add_w #(.W(4)) u4 (.a(a4), .b(b4), .s(s4));
  add_w #(.W(8)) u8 (.a(a8), .b(b8), .s(s8));

  initial begin
    a4 = 4'd15;
    b4 = 4'd1;
    a8 = 8'd200;
    b8 = 8'd100;
    #1;
    $display("INFO hier2.s4=%0d s8=%0d", s4, s8);
    if (s4 === 5'd16) $display("PASS hier2.param4");
    if (s8 === 9'd300) $display("PASS hier2.param8");
    $finish;
  end
endmodule
