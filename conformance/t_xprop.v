// Four-state behaviour: uninitialised values read as x, and x propagates.
module t_xprop;
  reg [3:0] unknown;
  reg [3:0] known;
  wire [3:0] sum;

  assign sum = known + unknown;

  initial begin
    known = 4'd1;
    #1;
    if (sum === 4'bxxxx) $display("PASS xprop.sum");
    else $display("FAIL xprop.sum got %b", sum);

    unknown = 4'd2;
    #1;
    if (sum == 4'd3) $display("PASS xprop.resolved");
    else $display("FAIL xprop.resolved got %0d", sum);

    $finish;
  end
endmodule
