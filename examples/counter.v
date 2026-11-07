// A four-bit counter with an asynchronous active-low reset.
// Demonstrates: clock generation, async reset, non-blocking assignment,
// continuous assignment and $display.
module counter_top;
  reg clk;
  reg rst_n;
  reg [3:0] q;
  wire carry;

  assign carry = (q == 4'hf);

  initial begin
    clk = 0;
    rst_n = 0;
    #12 rst_n = 1;
  end

  always #5 clk = ~clk;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      q <= 4'd0;
    else
      q <= q + 4'd1;
  end

  initial begin
    #100 $display("t=100 q=%d carry=%b", q, carry);
    $finish;
  end
endmodule
