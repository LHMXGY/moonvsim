// One always block driving several outputs.
module t_multi_out;
  reg  [3:0] a;
  wire [3:0] inc;
  wire [3:0] dec;
  wire       is_zero;
  wire       is_max;

  assign inc = a + 4'd1;
  assign dec = a - 4'd1;
  assign is_zero = (a == 4'd0);
  assign is_max = (a == 4'd15);

  initial begin
    a = 4'd0;
    #1;
    if (inc === 4'd1) $display("PASS multi_out.inc");
    if (dec === 4'd15) $display("PASS multi_out.underflow");
    if (is_zero === 1'b1) $display("PASS multi_out.zero");
    a = 4'd15;
    #1;
    if (is_max === 1'b1) $display("PASS multi_out.max");
    $finish;
  end
endmodule
