// Part-select and bit-select on the left hand side.
module t_part_lvalue;
  reg [15:0] word = 16'h0000;
  reg [3:0]  hi;
  reg        low;

  initial begin
    word[7:4] = 4'ha;
    word[0] = 1'b1;
    #1;
    hi = word[15:12];
    low = word[0];
    $display("INFO part_lvalue.word=%h", word);
    if (word === 16'h00a1) $display("PASS part_lvalue.assign");
    if (low === 1'b1) $display("PASS part_lvalue.bit_read");
    word[15:8] = 8'hff;
    #1;
    if (word === 16'hffa1) $display("PASS part_lvalue.overwrite");
    $finish;
  end
endmodule
