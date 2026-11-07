// 4-state propagation: x must survive arithmetic, comparison and reduction.
module t_xprop2;
  wire [3:0] a = 4'b10x1;
  wire [3:0] b = 4'b0011;
  wire [3:0] sum = a + b;
  wire [3:0] band = a & b;
  wire       eq = (a == b);
  wire       ceq = (a === b);

  initial begin
    #1;
    $display("INFO xprop2.sum=%b band=%b", sum, band);
    if (^sum === 1'bx) $display("PASS xprop2.sum_x");
    if (band === 4'b00x1) $display("PASS xprop2.and_x");
    if (eq === 1'bx) $display("PASS xprop2.eq_x");
    if (ceq === 1'b0) $display("PASS xprop2.ceq_known");
    $finish;
  end
endmodule
