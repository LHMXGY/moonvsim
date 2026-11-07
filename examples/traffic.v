// Traffic-light FSM: localparams, a clocked case and a combinational case.
module traffic_top;
  reg clk;
  reg rst_n;
  reg [1:0] state;
  reg [2:0] lights;

  localparam S_RED = 2'd0;
  localparam S_GREEN = 2'd1;
  localparam S_YELLOW = 2'd2;

  initial begin
    clk = 0;
    rst_n = 0;
    #7 rst_n = 1;
  end

  always #5 clk = ~clk;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_RED;
    else
      case (state)
        S_RED: state <= S_GREEN;
        S_GREEN: state <= S_YELLOW;
        default: state <= S_RED;
      endcase
  end

  always @(*) begin
    case (state)
      S_RED: lights = 3'b100;
      S_GREEN: lights = 3'b001;
      default: lights = 3'b010;
    endcase
  end

  initial begin
    #52 $display("state=%d lights=%b", state, lights);
    $finish;
  end
endmodule
