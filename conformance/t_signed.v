// Signed arithmetic: sign extension, arithmetic shift right, mixed compare.
module t_signed;
  wire signed [7:0] neg = -8'sd5;
  wire signed [7:0] pos = 8'sd3;
  wire signed [7:0] asr = neg >>> 1;
  wire signed [7:0] ssum = neg + pos;
  wire signed [15:0] sext = neg;
  wire               lt = neg < pos;

  initial begin
    #1;
    $display("INFO signed.asr=%0d ssum=%0d sext=%0d", $signed(asr), $signed(ssum), $signed(sext));
    if ($signed(asr) == -8'sd3) $display("PASS signed.asr");
    if ($signed(ssum) == -8'sd2) $display("PASS signed.add");
    if ($signed(sext) == -16'sd5) $display("PASS signed.sext");
    if (lt === 1'b1) $display("PASS signed.lt");
    $finish;
  end
endmodule
