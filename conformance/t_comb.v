// Combinational always @(*) versus continuous assign, with a mux tree.
module t_comb;
  reg  [1:0] sel;
  reg  [7:0] a;
  reg  [7:0] b;
  reg  [7:0] c;
  reg  [7:0] y;
  wire [7:0] z = y ^ 8'hff;

  always @(*) begin
    case (sel)
      2'd0: y = a;
      2'd1: y = b;
      2'd2: y = c;
      default: y = 8'h00;
    endcase
  end

  initial begin
    a = 8'h12;
    b = 8'h34;
    c = 8'h56;
    sel = 2'd1;
    #1;
    if (y === 8'h34) $display("PASS comb.mux_sel1");
    if (z === 8'hcb) $display("PASS comb.assign_follows");
    sel = 2'd2;
    #1;
    if (y === 8'h56) $display("PASS comb.mux_sel2");
    sel = 2'd3;
    #1;
    if (y === 8'h00) $display("PASS comb.mux_default");
    $finish;
  end
endmodule
