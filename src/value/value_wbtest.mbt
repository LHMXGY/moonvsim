// Unit tests for four-state bit vectors.

test "construct and format" {
  let a = Bits::from_uint(0xA5UL, 8)
  assert_eq(a.to_hex_string(), "a5")
  assert_eq(a.to_bin_string(), "10100101")
  assert_eq(a.to_dec_string(), "165")
  assert_eq(Bits::all_x(4).to_bin_string(), "xxxx")
  assert_eq(Bits::all_z(4).to_hex_string(), "z")
  assert_eq(Bits::from_uint(0xFFUL, 8).to_oct_string(), "377")
}

test "arithmetic" {
  let a = Bits::from_uint(10UL, 8)
  let b = Bits::from_uint(3UL, 8)
  assert_eq(a.badd(b).to_dec_string(), "13")
  assert_eq(a.bsub(b).to_dec_string(), "7")
  assert_eq(a.bmul(b).to_dec_string(), "30")
  assert_eq(a.bdiv(b).to_dec_string(), "3")
  assert_eq(a.bmod(b).to_dec_string(), "1")
  assert_eq(Bits::from_uint(0UL, 8).bneg().to_dec_string(), "0")
}

test "wraparound keeps width" {
  let a = Bits::from_uint(0xFFUL, 8)
  let r = a.badd(Bits::one(8))
  assert_eq(r.to_dec_string(), "0")
  assert_eq(r.to_hex_string(), "00")
}

test "unknown propagates through arithmetic" {
  let x = Bits::all_x(8)
  let one = Bits::one(8)
  assert_eq(x.badd(one).to_dec_string(), "x")
  assert_eq(x.band(Bits::zero(8)).to_dec_string(), "0")
  assert_eq(x.bor(Bits::from_uint(1UL, 8)).to_dec_string(), "x")
}

test "bitwise truth tables" {
  let x = Bits::all_x(4)
  let z = Bits::all_z(4)
  // 0 & x = 0
  assert_eq(Bits::zero(4).band(x).to_bin_string(), "0000")
  // 1 & x = x
  assert_eq(Bits::from_uint(0xFUL, 4).band(x).to_bin_string(), "xxxx")
  // x | 1 = 1 where the 1 is
  assert_eq(Bits::from_uint(0x1UL, 4).bor(x).to_bin_string(), "xxx1")
  // z behaves like x for logic operators
  assert_eq(z.band(Bits::zero(4)).to_bin_string(), "0000")
}

test "division by zero yields x" {
  let a = Bits::from_uint(7UL, 8)
  let zero = Bits::zero(8)
  assert_eq(a.bdiv(zero).to_dec_string(), "x")
  assert_eq(a.bmod(zero).to_dec_string(), "x")
}

test "shifts" {
  let a = Bits::from_uint(1UL, 8)
  assert_eq(a.bshl(Bits::from_uint(3UL, 8)).to_dec_string(), "8")
  assert_eq(Bits::from_uint(0x80UL, 8).bshr(Bits::from_uint(4UL, 8)).to_dec_string(), "8")
  // arithmetic shift of a negative value fills with ones
  let neg = Bits::from_sint(-8, 8)
  assert_eq(neg.bashr(Bits::from_uint(2UL, 8)).to_dec_string(), "-2")
}

test "signed comparison and division" {
  let a = Bits::from_sint(-4, 8)
  let b = Bits::from_sint(2, 8)
  assert_eq(a.blt(b).to_dec_string(), "1")
  assert_eq(a.bdiv(b).to_dec_string(), "-2")
  assert_eq(a.bmod(b).to_dec_string(), "0")
  assert_eq(Bits::from_sint(-6, 8).bmod(Bits::from_sint(4, 8)).to_dec_string(), "-2")
}

test "concat and select" {
  let hi = Bits::from_uint(0xAUL, 4)
  let lo = Bits::from_uint(0x5UL, 4)
  assert_eq(hi.concat(lo).to_hex_string(), "a5")
  let v = Bits::from_uint(0xABUL, 8)
  assert_eq(v.bit_sel(7).to_dec_string(), "1")
  assert_eq(v.bit_sel(0).to_dec_string(), "1")
  assert_eq(v.part_sel(7, 4).to_hex_string(), "a")
  assert_eq(v.part_sel(3, 0).to_hex_string(), "b")
  assert_eq(v.set_part(3, 0, Bits::from_uint(0x6UL, 4)).to_hex_string(), "a6")
  assert_eq(Bits::from_uint(0x3UL, 2).replicate(4).to_hex_string(), "ff")
}

test "reductions" {
  assert_eq(Bits::from_uint(0xFUL, 4).red_and().to_dec_string(), "1")
  assert_eq(Bits::from_uint(0xEUL, 4).red_and().to_dec_string(), "0")
  assert_eq(Bits::from_uint(0x0UL, 4).red_or().to_dec_string(), "0")
  assert_eq(Bits::from_uint(0x3UL, 4).red_xor().to_dec_string(), "0")
  assert_eq(Bits::from_uint(0x7UL, 4).red_xor().to_dec_string(), "1")
  assert_eq(Bits::all_x(4).red_and().to_dec_string(), "x")
  assert_eq(Bits::zero(4).red_and().to_dec_string(), "0")
}

test "case equality distinguishes x from 0" {
  let x = Bits::all_x(4)
  let z = Bits::all_z(4)
  assert_eq(x.bcase_eq(x).to_dec_string(), "1")
  assert_eq(x.bcase_eq(z).to_dec_string(), "0")
  assert_eq(x.beq(x).to_dec_string(), "x")
  assert_eq(x.bne(x).to_dec_string(), "x")
}

test "resize sign extends" {
  let a = Bits::from_sint(-2, 4)
  assert_eq(a.resize(8).to_dec_string(), "-2")
  let b = Bits::from_uint(0xFUL, 4)
  assert_eq(b.resize(8).to_dec_string(), "15")
  assert_eq(b.with_signed(true).resize(8).to_dec_string(), "-1")
}

test "format specifiers" {
  let v = Bits::from_uint(0x2AUL, 8)
  assert_eq(v.format('d', 4, false), "  42")
  assert_eq(v.format('d', 4, true), "0042")
  assert_eq(v.format('h', 4, true), "002a")
  assert_eq(v.format('b', 10, false), "  00101010")
}

