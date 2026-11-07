// A child module whose output is a reg driven by a clock, plus a second
// level of hierarchy.
module tick_gen (
  input      clk,
  input      rst,
  output reg pulse
);
  reg [1:0] cnt;

  always @(posedge clk) begin
    if (rst) begin
      cnt <= 2'd0;
      pulse <= 1'b0;
    end else begin
      cnt <= cnt + 2'd1;
      pulse <= (cnt == 2'd1);
    end
  end
endmodule

module top_tick (
  input      clk,
  input      rst,
  output     out
);
  wire p;
  tick_gen u_tick (.clk(clk), .rst(rst), .pulse(p));
  assign out = p;
endmodule

module t_hier_out;
  reg clk;
  reg rst;
  wire out;

  top_tick u_top (.clk(clk), .rst(rst), .out(out));

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    #12;
    rst = 0;
    #20;
    $display("INFO hier_out.out=%b", out);
    if (out === 1'b0) $display("PASS hier_out.pulse_low");
    if (u_top.u_tick.cnt === 2'd2) $display("PASS hier_out.nested_signal");
    $finish;
  end
endmodule
