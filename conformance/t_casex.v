// A 4-state selector must fall through to `default`, not match a label.
module t_casex;
  reg  [1:0] sel;
  reg  [3:0] y;

  always @(*) begin
    case (sel)
      2'd0: y = 4'h1;
      2'd1: y = 4'h2;
      default: y = 4'hf;
    endcase
  end

  initial begin
    sel = 2'd1;
    #1;
    if (y === 4'h2) $display("PASS casex.match");
    sel = 2'b1x;
    #1;
    if (y === 4'hf) $display("PASS casex.x_goes_default");
    $finish;
  end
endmodule
