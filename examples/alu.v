// Combinational ALU: `always @(*)` plus a `case` statement.
module alu_top;
  reg [3:0] a;
  reg [3:0] b;
  reg [1:0] op;
  reg [4:0] y;

  always @(*) begin
    case (op)
      2'd0: y = a + b;
      2'd1: y = a - b;
      2'd2: y = a & b;
      2'd3: y = a | b;
      default: y = 5'd0;
    endcase
  end

  initial begin
    a = 4'd7;
    b = 4'd3;
    op = 2'd0;
    #1 $display("add=%d", y);
    op = 2'd1;
    #1 $display("sub=%d", y);
    op = 2'd2;
    #1 $display("and=%d", y);
    op = 2'd3;
    #1 $display("or=%d", y);
    $finish;
  end
endmodule
