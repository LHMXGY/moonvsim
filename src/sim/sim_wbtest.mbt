// End-to-end engine tests: parse -> elaborate -> simulate.

///|
fn build(src : String) -> (@elaborate.Netlist, Sim) raise {
  let (design, errs) = @parser.parse(src)
  if errs.length() > 0 {
    fail("parse errors: \{errs}")
  }
  let net = @elaborate.elaborate(design)
  (net, Sim::new(net))
}

///|
fn expect_u64(
  sim : Sim,
  net : @elaborate.Netlist,
  name : String,
  want : UInt64,
) -> Unit raise {
  match @elaborate.find_sig(net, name) {
    Some(id) => {
      let got = sim.read(id)
      if !got.is_known() {
        fail("\{name} is not fully known: \{got.to_bin_string()}")
      }
      if got.to_uint64() != want {
        fail("\{name} = \{got.to_dec_string()}, want \{want}")
      }
    }
    None => fail("no signal named \{name}")
  }
}

///|
test "clocked counter increments on posedge" {
  let src =
    #|module top;
    #|  reg clk;
    #|  reg [3:0] q;
    #|  initial begin
    #|    clk = 0;
    #|    q = 0;
    #|  end
    #|  always #5 clk = ~clk;
    #|  always @(posedge clk) begin
    #|    q <= q + 1;
    #|  end
    #|endmodule
  let (net, sim) = build(src)
  sim.run(52L)
  expect_u64(sim, net, "q", 5UL)
}

///|
test "continuous assign adds with carry" {
  let src =
    #|module top;
    #|  reg [7:0] a;
    #|  reg [7:0] b;
    #|  wire [8:0] s;
    #|  assign s = a + b;
    #|  initial begin
    #|    a = 8'hff;
    #|    b = 8'h01;
    #|  end
    #|endmodule
  let (net, sim) = build(src)
  sim.step_once()
  expect_u64(sim, net, "a", 255UL)
  expect_u64(sim, net, "b", 1UL)
  match @elaborate.find_sig(net, "s") {
    Some(id) =>
      if sim.read(id).to_uint64() != 256UL {
        fail("s = \{sim.read(id).to_dec_string()}, want 256")
      }
    None => fail("no signal s")
  }
}

///|
test "non-blocking swap is atomic" {
  let src =
    #|module top;
    #|  reg a;
    #|  reg b;
    #|  initial begin
    #|    a = 0;
    #|    b = 1;
    #|    a <= b;
    #|    b <= a;
    #|  end
    #|endmodule
  let (net, sim) = build(src)
  sim.step_once()
  expect_u64(sim, net, "a", 1UL)
  expect_u64(sim, net, "b", 0UL)
}

///|
test "$display records formatted output" {
  let src =
    #|module top;
    #|  reg [7:0] v;
    #|  initial begin
    #|    v = 8'd42;
    #|    $display("v=%d hex=%h", v, v);
    #|    $finish;
    #|  end
    #|endmodule
  let (_, sim) = build(src)
  sim.run(10L)
  if sim.messages.length() != 1 {
    fail("expected one message, got \{sim.messages.length()}")
  }
  if sim.messages[0] != "v=42 hex=2a" {
    fail("message was \{sim.messages[0]}")
  }
}
