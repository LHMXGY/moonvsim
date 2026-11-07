// Case items with several labels share one statement.
module t_case_multi;
  reg [2:0] sel;
  reg [3:0] y;

  always @(*) begin
    case (sel)
      3'd0, 3'd1, 3'd2: y = 4'h1;
      3'd3, 3'd4: y = 4'h2;
      3'd5: y = 4'h4;
      default: y = 4'h8;
    endcase
  end

  initial begin
    sel = 3'd2;
    #1;
    if (y === 4'h1) $display("PASS case_multi.grp0");
    sel = 3'd4;
    #1;
    if (y === 4'h2) $display("PASS case_multi.grp1");
    sel = 3'd7;
    #1;
    if (y === 4'h8) $display("PASS case_multi.default");
    $finish;
  end
endmodule
