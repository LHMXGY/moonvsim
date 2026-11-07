// Procedural loops and delay control inside initial.
module t_loop;
  integer acc;
  integer n;
  reg [7:0] pipe [0:3];
  integer k;
  reg       clk;

  always #5 clk = ~clk;

  initial begin
    acc = 0;
    for (k = 1; k <= 4; k = k + 1) acc = acc + k;
    n = 0;
    while (n < 3) n = n + 1;
    if (acc == 10) $display("PASS loop.for_sum");
    if (n == 3) $display("PASS loop.while");
    repeat (2) acc = acc + 1;
    if (acc == 12) $display("PASS loop.repeat");

    pipe[0] = 8'd7;
    for (k = 1; k < 4; k = k + 1) pipe[k] = 8'd0;
    #12;
    $display("INFO loop.acc=%0d pipe0=%0d", acc, pipe[0]);
    if (acc == 12) $display("PASS loop.after_delay");
    $finish;
  end
endmodule
