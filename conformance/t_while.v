// while and repeat loops inside an initial block.
module t_while;
  reg [7:0] acc;
  reg [3:0] i;
  reg [3:0] n;

  initial begin
    acc = 8'd0;
    i = 4'd0;
    while (i < 4'd4) begin
      acc = acc + i;
      i = i + 4'd1;
    end
    if (acc === 8'd6) $display("PASS while.sum");

    n = 4'd0;
    repeat (3) n = n + 4'd2;
    if (n === 4'd6) $display("PASS while.repeat");
    $finish;
  end
endmodule
