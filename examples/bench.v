// Synthetic throughput benchmark: a 16-bit LFSR, a 32-bit accumulator and a
// small combinational datapath, all clocked for as long as the run allows.
// Used by `bench/run_bench.py` to report simulated cycles per second.

module lfsr16 (
  input clk,
  input rst,
  output reg [15:0] q
);

always @(posedge clk) begin
  if (rst) begin
    q <= 16'hace1;
  end else begin
    q <= {q[14:0], q[15] ^ q[13] ^ q[12] ^ q[10]};
  end
end

endmodule

module accum32 (
  input clk,
  input rst,
  input [15:0] din,
  output reg [31:0] sum,
  output reg [31:0] prod
);

always @(posedge clk) begin
  if (rst) begin
    sum <= 32'd0;
    prod <= 32'd1;
  end else begin
    sum <= sum + {16'd0, din};
    prod <= prod * 32'd1_664_525 + 32'd1_013_904_223;
  end
end

endmodule

module datapath (
  input [15:0] a,
  input [15:0] b,
  output [16:0] add,
  output [15:0] xormix,
  output [7:0] byteswap
);

assign add = {1'b0, a} + {1'b0, b};
assign xormix = a ^ (b + 16'h5a5a);
assign byteswap = {a[3:0], a[7:4], a[11:8], a[15:12]};

endmodule

module bench_tb;

reg clk;
reg rst;
wire [15:0] lfsr;
wire [31:0] sum;
wire [31:0] prod;
wire [16:0] add;
wire [15:0] xormix;
wire [7:0] byteswap;

lfsr16 u_lfsr (
  .clk(clk),
  .rst(rst),
  .q(lfsr)
);

accum32 u_acc (
  .clk(clk),
  .rst(rst),
  .din(lfsr),
  .sum(sum),
  .prod(prod)
);

datapath u_dp (
  .a(lfsr),
  .b(sum[15:0]),
  .add(add),
  .xormix(xormix),
  .byteswap(byteswap)
);

initial begin
  clk = 0;
  rst = 1;
  $display("bench start");
  #20;
  rst = 0;
  #199_980;
  $display("bench done sum=%h prod=%h", sum, prod);
  $finish;
end

always #5 clk = ~clk;

always @(posedge clk) begin
  if (sum > 32'hffff_0000) begin
    $display("bench checkpoint sum=%h prod=%h", sum, prod);
  end
end

endmodule
