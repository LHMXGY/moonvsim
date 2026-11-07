// Hierarchy: a leaf module instantiated with named and positional ports.
module inv(input a, output y);
  assign y = ~a;
endmodule

module t_hier;
  reg a;
  wire y;
  wire z;

  inv u1(.a(a), .y(y));
  inv u2(a, z);

  initial begin
    a = 0;
    #1;
    if (y == 1'b1 && z == 1'b1) $display("PASS hier.invert0");
    else $display("FAIL hier.invert0 y=%b z=%b", y, z);

    a = 1;
    #1;
    if (y == 1'b0 && z == 1'b0) $display("PASS hier.invert1");
    else $display("FAIL hier.invert1 y=%b z=%b", y, z);

    $finish;
  end
endmodule
