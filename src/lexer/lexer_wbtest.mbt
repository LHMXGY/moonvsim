// Lexer tests.

///|
fn toks_of(src : String) -> Array[Token] {
  let (t, _errs) = tokenize(src)
  t
}

///|
test "sized literals" {
  let t = toks_of("8'hFF 4'b10x0 3'o7 12'd255")
  assert_eq(t.length(), 5)
  let b0 = match t[0].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b0.to_hex_string(), "ff")
  assert_eq(b0.width, 8)
  let b1 = match t[1].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b1.to_bin_string(), "10x0")
  let b2 = match t[2].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b2.to_oct_string(), "7")
  let b3 = match t[3].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b3.to_dec_string(), "255")
}

///|
test "unsized and x/z literals" {
  let t = toks_of("42 'hA 8'hzz 8'b0000_1111")
  assert_eq(t.length(), 5)
  let b0 = match t[0].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b0.width, 32)
  assert_eq(b0.to_dec_string(), "42")
  let b2 = match t[2].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b2.to_bin_string(), "zzzzzzzz")
  let b3 = match t[3].kind {
    Number(b) => b
    _ => fail("expected number")
  }
  assert_eq(b3.to_bin_string(), "00001111")
}

///|
test "identifiers and punctuation" {
  let t = toks_of(
    "module m; input clk; always @(posedge clk) q <= d; endmodule",
  )
  assert_eq(t.length(), 18)
  match t[0].kind {
    Ident(s) => assert_eq(s, "module")
    _ => fail("expected ident")
  }
  match t[7].kind {
    Punct(s) => assert_eq(s, "@")
    _ => fail("expected punct")
  }
  match t[13].kind {
    Punct(s) => assert_eq(s, "<=")
    _ => fail("expected <=")
  }
}

///|
test "comments and strings" {
  let t = toks_of("// a\n/* b\nc */ x 1 \"hi \\\" you\"")
  assert_eq(t.length(), 4)
  match t[2].kind {
    Str(s) => assert_eq(s, "hi \" you")
    _ => fail("expected string")
  }
}

///|
test "system identifiers" {
  let t = toks_of("$display $finish")
  assert_eq(t.length(), 3)
  match t[0].kind {
    Ident(s) => assert_eq(s, "$display")
    _ => fail("expected ident")
  }
}
