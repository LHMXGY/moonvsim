// A combinational for loop that builds a parity bit.
module t_for_always;
  reg  [7:0] v;
  reg        parity;
  integer    i;

  always @(*) begin
    parity = 1'b0;
    for (i = 0; i < 8; i = i + 1) parity = parity ^ v[i];
  end

  initial begin
    v = 8'b1011_0010;
    #1;
    if (parity === 1'b1) $display("PASS for_always.odd");
    v = 8'b1111_0000;
    #1;
    if (parity === 1'b0) $display("PASS for_always.even");
    $finish;
  end
endmodule
