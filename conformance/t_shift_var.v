// Variable shift amounts, both directions and arithmetic.
module t_shift_var;
  reg [7:0] v;
  reg [2:0] n;
  reg [7:0] l;
  reg [7:0] r;
  reg signed [7:0] s;
  reg signed [7:0] a;

  always @(*) begin
    l = v << n;
    r = v >> n;
    a = s >>> n;
  end

  initial begin
    v = 8'b1000_1010;
    n = 3'd2;
    s = -8'sd64;
    #1;
    if (l === 8'b0010_1000) $display("PASS shift_var.left");
    if (r === 8'b0010_0010) $display("PASS shift_var.right");
    if (a === -8'sd16) $display("PASS shift_var.arithmetic");
    n = 3'd7;
    #1;
    if (l === 8'b0000_0000) $display("PASS shift_var.left_long");
    $finish;
  end
endmodule
