// Concatenation, partial selects and replication with expressions.
module t_concat2;
  reg  [7:0] a;
  reg  [3:0] b;
  wire [3:0] nib = a[7:4];
  wire [7:0] joined = {a[3:0], b};
  wire [3:0] rep = {4{a[0]}};
  wire [5:0] mix = {a[0], b[3:2], 3'b101};

  initial begin
    a = 8'b1010_0110;
    b = 4'b1100;
    #1;
    $display("INFO concat2.nib=%b joined=%b rep=%b mix=%b", nib, joined, rep, mix);
    if (nib === 4'b1010) $display("PASS concat2.nibble");
    if (joined === 8'b0110_1100) $display("PASS concat2.join");
    if (rep === 4'b0000) $display("PASS concat2.repl_zero");
    if (mix === 6'b0_11_101) $display("PASS concat2.mix");
    $finish;
  end
endmodule
