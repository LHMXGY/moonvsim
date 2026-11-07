// `always` without an edge list that contains a delay: a free running clock
// divider style loop.
module t_repeat2;
  reg       fast;
  reg [3:0] ticks;

  always begin
    #3 fast = ~fast;
  end

  always @(posedge fast) ticks = ticks + 4'd1;

  initial begin
    fast = 0;
    ticks = 0;
    #30;
    $display("INFO repeat2.fast=%b ticks=%0d", fast, ticks);
    if (ticks == 5) $display("PASS repeat2.divider");
    $finish;
  end
endmodule
