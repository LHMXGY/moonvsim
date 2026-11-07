// Parameter overrides on a module instance.
module adder #(parameter W = 8) (input [W-1:0] a, input [W-1:0] b, output [W:0] s);
  assign s = a + b;
endmodule

module t_param;
  reg [3:0] a4;
  reg [3:0] b4;
  wire [4:0] s4;

  adder #(.W(4)) u4(.a(a4), .b(b4), .s(s4));

  initial begin
    a4 = 4'd9;
    b4 = 4'd8;
    #1;
    if (s4 == 5'd17) $display("PASS param.w4");
    else $display("FAIL param.w4 got %0d", s4);
    $finish;
  end
endmodule
