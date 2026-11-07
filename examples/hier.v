// Hierarchy: a leaf module instantiated with named port connections, driven by
// a top-level testbench.
module inv(input a, output y);
  assign y = ~a;
endmodule

module hier_top;
  reg a;
  wire y;

  inv u1(.a(a), .y(y));

  initial begin
    a = 0;
    #1 $display("a=0 y=%b", y);
    a = 1;
    #1 $display("a=1 y=%b", y);
    $finish;
  end
endmodule
