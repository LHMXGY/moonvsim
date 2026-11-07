// A small design used by the waveform demo: a counter, a shift register and a
// two-state controller sharing one clock.
module wave (
  input clk,
  input rst,
  output [3:0] cnt,
  output [7:0] shreg,
  output [1:0] state,
  output busy
);

  reg [3:0] count;
  reg [7:0] shift;
  reg [1:0] st;
  reg       waiting;

  always @(posedge clk) begin
    if (rst) begin
      count <= 4'd0;
      shift <= 8'b1010_0101;
      st <= 2'd0;
      waiting <= 1'b0;
    end else begin
      count <= count + 4'd1;
      shift <= {shift[6:0], shift[7]};
      case (st)
        2'd0: begin
          st <= 2'd1;
          waiting <= 1'b1;
        end
        2'd1: begin
          if (count == 4'd5) begin
            st <= 2'd2;
            waiting <= 1'b0;
          end
        end
        default: begin
          if (count == 4'd9) st <= 2'd0;
        end
      endcase
    end
  end

  assign cnt = count;
  assign shreg = shift;
  assign state = st;
  assign busy = waiting;
endmodule

module wave_tb;
  reg clk;
  reg rst;

  wave dut (
    .clk(clk),
    .rst(rst),
    .cnt(),
    .shreg(),
    .state(),
    .busy()
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    #12;
    rst = 0;
    #188;
    $display("done cnt=%0d state=%0d", dut.count, dut.st);
    $finish;
  end
endmodule
