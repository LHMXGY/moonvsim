// Width rules on wide values and truncating multiply.
module t_wide;
  wire [31:0] a = 32'hffff_ffff;
  wire [31:0] one = 32'd1;
  wire [32:0] carry = a + one;
  wire [31:0] wrap = a + one;
  wire [31:0] mul = 32'h1_0001 * 32'h1_0001;
  wire [63:0] wide = 64'hffff_ffff_ffff_ffff;

  initial begin
    $display("INFO wide.carry=%h wrap=%h mul=%h", carry, wrap, mul);
    if (carry === 33'h1_0000_0000) $display("PASS wide.carry");
    if (wrap === 32'h0) $display("PASS wide.wrap");
    if (mul === 32'h0002_0001) $display("PASS wide.mul_trunc");
    if (wide + 64'd1 === 64'h0) $display("PASS wide.wrap64");
    $finish;
  end
endmodule
