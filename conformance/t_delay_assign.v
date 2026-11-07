// Delayed assignments inside an initial block.
module t_delay_assign;
  reg [3:0] x;

  initial begin
    x = 4'd1;
    #4 x = 4'd2;
    #4 x = 4'd4;
    #4;
    if (x === 4'd4) $display("PASS delay_assign.value");
    $finish;
  end
endmodule
