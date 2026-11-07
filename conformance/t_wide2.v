// 64 bit arithmetic and truncation.
module t_wide2;
  reg [63:0] a;
  reg [63:0] b;
  wire [63:0] sum;
  wire [63:0] prod;
  wire [31:0] lo;

  assign sum = a + b;
  assign prod = a * b;
  assign lo = (a * b) >> 32;

  initial begin
    a = 64'h0000_0000_1234_5678;
    b = 64'h0000_0000_0000_0002;
    #1;
    if (sum === 64'h0000_0000_2468_acf0) $display("PASS wide2.sum");
    if (prod === 64'h0000_0000_2468_acf0) $display("PASS wide2.mul_shift");
    a = 64'hffff_ffff_ffff_ffff;
    b = 64'h0000_0000_0000_0001;
    #1;
    if (sum === 64'd0) $display("PASS wide2.wrap");
    if (lo === 32'd0) $display("PASS wide2.truncate");
    $finish;
  end
endmodule
