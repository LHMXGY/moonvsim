// Operator coverage: modulo, power, xnor, nand/nor reductions.
module t_ops2;
  reg [3:0] a;
  reg [3:0] b;

  initial begin
    a = 4'd9;
    b = 4'd4;
    #1;
    if (a % b === 4'd1) $display("PASS ops2.mod");
    if (a ** 4'd2 === 4'd81) $display("PASS ops2.pow");
    if ((a ^~ b) === 4'b1101) $display("PASS ops2.xnor");
    if (~&a === 1'b1) $display("PASS ops2.nand_reduce");
    if (~|b === 1'b1) $display("PASS ops2.nor_reduce");
    $finish;
  end
endmodule
