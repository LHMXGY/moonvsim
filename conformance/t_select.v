// Part selects, bit selects, concatenation and replication.
module t_select;
  reg [7:0] a;
  reg [3:0] hi, lo;
  reg [7:0] cat;

  initial begin
    a = 8'b1010_0110;
    hi = a[7:4];
    lo = a[3:0];
    #1;
    if (hi == 4'b1010) $display("PASS select.hi");
    else $display("FAIL select.hi");
    if (lo == 4'b0110) $display("PASS select.lo");
    else $display("FAIL select.lo");

    cat = {hi, lo};
    #1;
    if (cat == a) $display("PASS select.concat");
    else $display("FAIL select.concat");

    cat = {4{2'b10}};
    #1;
    if (cat == 8'b1010_1010) $display("PASS select.repl");
    else $display("FAIL select.repl");

    cat = {a[0], a[7:1]};
    #1;
    if (cat == 8'b0101_0011) $display("PASS select.rotate");
    else $display("FAIL select.rotate");

    $finish;
  end
endmodule
