// Logical, comparison and conditional operators.
module t_logic;
  reg [7:0] a, b;

  initial begin
    a = 8'd10;
    b = 8'd20;

    if (a < b) $display("PASS logic.lt");
    else $display("FAIL logic.lt");

    if (a != b) $display("PASS logic.ne");
    else $display("FAIL logic.ne");

    if (!(a == b)) $display("PASS logic.eq");
    else $display("FAIL logic.eq");

    if ((a && b) == 1'b1) $display("PASS logic.land");
    else $display("FAIL logic.land");

    if ((a > b ? a : b) == 8'd20) $display("PASS logic.max");
    else $display("FAIL logic.max");

    $finish;
  end
endmodule
