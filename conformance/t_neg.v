// Negative-edge logic and a register that toggles on both edges of a clock.
module t_neg;
  reg       clk;
  reg [3:0] down;
  reg [3:0] both;

  always #5 clk = ~clk;

  always @(negedge clk) down = down + 4'd1;

  always @(clk) both = both + 4'd1;

  initial begin
    clk = 0;
    down = 0;
    both = 0;
    #52;
    $display("INFO neg.down=%0d both=%0d", down, both);
    if (down == 5) $display("PASS neg.negedge_count");
    if (both == 10) $display("PASS neg.both_edges");
    $finish;
  end
endmodule
