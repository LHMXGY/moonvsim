// Nested if/else priority encoder.
module t_priority;
  reg  [3:0] req;
  reg  [1:0] grant;
  reg        any;

  always @(*) begin
    any = 1'b1;
    if (req[3]) grant = 2'd3;
    else if (req[2]) grant = 2'd2;
    else if (req[1]) grant = 2'd1;
    else if (req[0]) grant = 2'd0;
    else begin
      grant = 2'd0;
      any = 1'b0;
    end
  end

  initial begin
    req = 4'b0000;
    #1;
    if (any === 1'b0) $display("PASS priority.none");
    req = 4'b0100;
    #1;
    if (grant === 2'd2) $display("PASS priority.mid");
    req = 4'b1001;
    #1;
    if (grant === 2'd3) $display("PASS priority.top_wins");
    $finish;
  end
endmodule
