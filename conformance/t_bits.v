// Bitwise, reduction and shift operators.
module t_bits;
  reg [7:0] a, b;

  initial begin
    a = 8'b1100_1010;
    b = 8'b1111_0000;

    if ((a & b) == 8'b1100_0000) $display("PASS bits.and");
    else $display("FAIL bits.and");

    if ((a | b) == 8'b1111_1010) $display("PASS bits.or");
    else $display("FAIL bits.or");

    if ((a ^ b) == 8'b0011_1010) $display("PASS bits.xor");
    else $display("FAIL bits.xor");

    if ((~a) == 8'b0011_0101) $display("PASS bits.not");
    else $display("FAIL bits.not");

    if (a << 2 == 8'b0010_1000) $display("PASS bits.shl");
    else $display("FAIL bits.shl");

    if (a >> 3 == 8'b0001_1001) $display("PASS bits.shr");
    else $display("FAIL bits.shr");

    if (&b == 1'b0) $display("PASS bits.redand");
    else $display("FAIL bits.redand");

    if (|b == 1'b1) $display("PASS bits.redor");
    else $display("FAIL bits.redor");

    if (^a == 1'b0) $display("PASS bits.redxor");
    else $display("FAIL bits.redxor");

    $finish;
  end
endmodule
