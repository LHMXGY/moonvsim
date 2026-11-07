// Mixed signedness in comparisons and assignments.
module t_signed_mix;
  reg signed [7:0] s;
  reg        [7:0] u;
  reg              lt;

  always @(*) lt = s < u;

  initial begin
    s = -8'sd1;
    u = 8'd1;
    #1;
    if (lt === 1'b1) $display("PASS signed_mix.signed_compare");
    s = 8'sd5;
    u = 8'd200;
    #1;
    if (lt === 1'b1) $display("PASS signed_mix.unsigned_compare");
    if ($signed(u) < 0) $display("PASS signed_mix.cast_negative");
    $finish;
  end
endmodule
