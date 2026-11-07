// Declaration initialisers on both nets and variables, plus an if/else chain
// driven by a parameter.
module t_ifdecl #(
  parameter MODE = 1
) ();
  wire [3:0] net = 4'b1010;
  reg  [3:0] var = 4'b0101;
  reg  [3:0] out;

  always @(*) begin
    if (MODE == 0) out = net;
    else if (MODE == 1) out = var;
    else out = net ^ var;
  end

  initial begin
    #1;
    if (net === 4'b1010) $display("PASS ifdecl.net_init");
    if (var === 4'b0101) $display("PASS ifdecl.var_init");
    if (out === 4'b0101) $display("PASS ifdecl.param_branch");
    $finish;
  end
endmodule
