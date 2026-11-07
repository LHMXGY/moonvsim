// z handling: z is not x, and case equality separates them.
module t_zprop;
  wire [3:0] t = 4'bz0z0;
  wire       anyz = (t === 4'bz0z0);
  wire       r_and = &t;
  wire       r_or = |t;

  initial begin
    #1;
    $display("INFO zprop.t=%b rand=%b ror=%b", t, r_and, r_or);
    if (anyz === 1'b1) $display("PASS zprop.match");
    if (r_and === 1'bx) $display("PASS zprop.redand_x");
    if (r_or === 1'b1) $display("PASS zprop.redor_one");
    $finish;
  end
endmodule
