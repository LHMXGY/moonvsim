// case / default selection.
module t_case;
  reg [2:0] sel;
  reg [3:0] out;

  always @(*) begin
    case (sel)
      3'd0: out = 4'b0001;
      3'd1: out = 4'b0010;
      3'd2: out = 4'b0100;
      default: out = 4'b1000;
    endcase
  end

  initial begin
    sel = 3'd0;
    #1;
    if (out == 4'b0001) $display("PASS case.zero");
    else $display("FAIL case.zero");

    sel = 3'd2;
    #1;
    if (out == 4'b0100) $display("PASS case.two");
    else $display("FAIL case.two");

    sel = 3'd5;
    #1;
    if (out == 4'b1000) $display("PASS case.default");
    else $display("FAIL case.default");

    $finish;
  end
endmodule
