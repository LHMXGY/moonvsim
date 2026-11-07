// $display formatting: decimal, hex, binary, character and time.
module t_display;
  reg [7:0] v;

  initial begin
    v = 8'd42;
    #3;
    $display("dec=%0d hex=%h bin=%b oct=%o char=%c", v, v, v, v, "A");
    $display("time=%0t", 7);
    $display("PASS display.format");
    $finish;
  end
endmodule
