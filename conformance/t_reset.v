// Synchronous and asynchronous reset styles side by side.
module t_reset;
  reg       clk;
  reg       arst;
  reg [3:0] async_cnt;
  reg [3:0] sync_cnt;

  always #5 clk = ~clk;

  always @(posedge clk or posedge arst) begin
    if (arst) async_cnt <= 4'd0;
    else async_cnt <= async_cnt + 4'd1;
  end

  always @(posedge clk) begin
    if (arst) sync_cnt <= 4'd0;
    else sync_cnt <= sync_cnt + 4'd1;
  end

  initial begin
    clk = 0;
    arst = 0;
    #22;
    arst = 1;
    #3;
    $display("INFO reset.async=%0d sync=%0d", async_cnt, sync_cnt);
    if (async_cnt === 4'd0) $display("PASS reset.async_clear");
    if (sync_cnt === 4'd2) $display("PASS reset.sync_waits_for_clock");
    arst = 0;
    #12;
    if (async_cnt === 4'd1) $display("PASS reset.restart");
    $finish;
  end
endmodule
