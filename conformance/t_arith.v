// 8-bit arithmetic in an 8-bit context wraps; a 9-bit target keeps the carry.
module t_arith;
  reg [7:0] a, b;
  reg [8:0] s;

  initial begin
    a = 8'd200;
    b = 8'd100;
    #1;
    if ((a + b) == 8'd44) $display("PASS arith.wrap8");
    else $display("FAIL arith.wrap8 got %0d", a + b);

    s = a + b;
    #1;
    if (s == 9'd300) $display("PASS arith.ctx9");
    else $display("FAIL arith.ctx9 got %0d", s);

    if (8'hff + 8'h01 == 8'h00) $display("PASS arith.selfdet");
    else $display("FAIL arith.selfdet");

    if (8'd7 - 8'd10 == 8'd253) $display("PASS arith.sub");
    else $display("FAIL arith.sub");

    if (8'd13 * 8'd7 == 8'd91) $display("PASS arith.mul");
    else $display("FAIL arith.mul");

    if (8'd91 / 8'd7 == 8'd13) $display("PASS arith.div");
    else $display("FAIL arith.div");

    if (8'd91 % 8'd7 == 8'd0) $display("PASS arith.mod");
    else $display("FAIL arith.mod");

    $finish;
  end
endmodule
