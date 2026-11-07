// Variable bit select, indexed part select and out-of-range reads.
module t_select2;
  reg  [7:0] d;
  reg  [2:0] i;
  wire       bit_v = d[i];
  wire [3:0] part_v = d[i +: 4];
  wire [3:0] part_lo = d[7 -: 4];

  initial begin
    d = 8'b1011_0110;
    i = 3'd2;
    #1;
    $display("INFO select2.bit=%b part=%b lo=%b", bit_v, part_v, part_lo);
    if (bit_v === 1'b1) $display("PASS select2.bit");
    if (part_v === 4'b1101) $display("PASS select2.part_plus");
    if (part_lo === 4'b1011) $display("PASS select2.part_minus");
    i = 3'd7;
    d = 8'hff;
    #1;
    if (d[i] === 1'b1) $display("PASS select2.index7");
    $finish;
  end
endmodule
