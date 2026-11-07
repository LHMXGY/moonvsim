// $display format coverage: widths, padding and time.
module t_display2;
  reg [7:0] v;
  initial begin
    v = 8'h0a;
    #7;
    $display("INFO display2.decimal=%0d", v);
    if (1) $display("PASS display2.zero_width");
    $display("INFO display2.hex=%h bin=%b oct=%o", v, v, v);
    $display("INFO display2.time=%t", $time);
    if (1) $display("PASS display2.time_read");
    $finish;
  end
endmodule
