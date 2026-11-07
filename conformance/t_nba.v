// Blocking vs non-blocking ordering, and a three-stage shift pipeline.
module t_nba;
  reg       clk;
  reg [3:0] blk;
  reg [3:0] nba;
  reg [3:0] s0;
  reg [3:0] s1;
  reg [3:0] s2;

  always #5 clk = ~clk;

  // blocking chain: all three assignments land in one evaluation
  always @(posedge clk) begin
    blk = blk + 4'd1;
    blk = blk + 4'd1;
  end

  // non-blocking chain: old value of the right hand side is used
  always @(posedge clk) begin
    nba <= nba + 4'd1;
    nba <= nba + 4'd1;
  end

  always @(posedge clk) begin
    s0 <= 4'd1;
    s1 <= s0;
    s2 <= s1;
  end

  initial begin
    clk = 0;
    blk = 0;
    nba = 0;
    s0 = 0;
    s1 = 0;
    s2 = 0;
    #52;
    $display("INFO nba.blk=%0d nba=%0d s0=%0d s1=%0d s2=%0d", blk, nba, s0, s1, s2);
    if (blk == 10) $display("PASS nba.blocking_order");
    if (nba == 5) $display("PASS nba.nonblocking_order");
    if (s2 == 4'd1) $display("PASS nba.pipeline_latency");
    if (s0 == 4'd1 && s1 == 4'd1) $display("PASS nba.pipeline_fill");
    $finish;
  end
endmodule
