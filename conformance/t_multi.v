// Several processes over the same registers plus a continuous assignment.
module t_multi;
  reg       clk;
  reg [3:0] cnt;
  reg [3:0] inv;
  wire      carry;

  always #5 clk = ~clk;

  always @(posedge clk) cnt <= cnt + 4'd1;

  always @(posedge clk) inv <= cnt + 4'd1;

  assign carry = (cnt == 4'd3);

  initial begin
    clk = 0;
    cnt = 0;
    inv = 0;
    #46;
    $display("INFO multi.cnt=%0d inv=%0d carry=%b", cnt, inv, carry);
    if (cnt == 5) $display("PASS multi.counter");
    if (inv == 5) $display("PASS multi.shadow_uses_old_value");
    if (carry === 1'b0) $display("PASS multi.assign_tracks");
    $finish;
  end
endmodule
