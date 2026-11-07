// Clocked logic: non-blocking assignment, a counter and a shift register.
module t_clock;
  reg clk;
  reg rst_n;
  reg [3:0] count;
  reg [3:0] shreg;
  reg din;

  initial begin
    clk = 0;
    rst_n = 0;
    din = 0;
    #7 rst_n = 1;
  end

  always #5 clk = ~clk;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 4'd0;
      shreg <= 4'd0;
    end else begin
      count <= count + 4'd1;
      shreg <= {shreg[2:0], din};
    end
  end

  initial begin
    #2 din = 1;
    #10 din = 0;
    #20 din = 1;
    #30 $display("count=%0d shreg=%b", count, shreg);
    if (count == 4'd5) $display("PASS clock.count");
    else $display("FAIL clock.count got %0d", count);
    if (shreg == 4'b0111) $display("PASS clock.shift");
    else $display("FAIL clock.shift got %b", shreg);
    $finish;
  end
endmodule
