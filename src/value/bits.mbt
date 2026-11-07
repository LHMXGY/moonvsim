// moonvsim - a MoonBit-native Verilog-2001 RTL simulator.
// Four-state (0/1/x/z) bit vectors up to 64 bits wide.

/// The four logic values of a Verilog net or variable.
pub(all) enum Logic {
  Zero
  One
  X
  Z
}

/// The character Verilog uses to print this logic value.
pub fn Logic::to_char(self : Logic) -> Char {
  match self {
    Zero => '0'
    One => '1'
    X => 'x'
    Z => 'z'
  }
}

/// True for 0 and 1.
pub fn Logic::is_known(self : Logic) -> Bool {
  match self {
    Zero | One => true
    X | Z => false
  }
}

/// Bitwise complement of all 64 bits.
fn n64(x : UInt64) -> UInt64 {
  x ^ 0xFFFF_FFFF_FFFF_FFFFUL
}

/// A fixed-width four-state value.
///
/// `val` holds the bits that are known to be 1, `unk` holds the bits that are
/// not known to be 0 or 1, and `zed` is the subset of `unk` that is high
/// impedance instead of unknown.  Bits above `width` are always zero.
pub(all) struct Bits {
  width : Int32
  val : UInt64
  unk : UInt64
  zed : UInt64
  signed : Bool
}

/// Mask of the low `width` bits.  `width` must be in `1..=64`.
pub fn mask_of(width : Int32) -> UInt64 {
  if width >= 64 {
    0xFFFF_FFFF_FFFF_FFFFUL
  } else if width <= 0 {
    0UL
  } else {
    (1UL << width) - 1UL
  }
}

/// Bits of `x` that are known to be zero.
pub fn known_zeros(x : Bits) -> UInt64 {
  n64(x.val | x.unk) & mask_of(x.width)
}

/// Bits of `x` that are known to be one.
pub fn known_ones(x : Bits) -> UInt64 {
  x.val & mask_of(x.width)
}

/// Convenience constructor that clears out-of-range bits.
pub fn Bits::make(
  width : Int32,
  val : UInt64,
  unk : UInt64,
  zed : UInt64,
) -> Bits {
  let m = mask_of(width)
  {
    width: width,
    val: val & m & n64(unk),
    unk: unk & m,
    zed: zed & unk & m,
    signed: false,
  }
}

/// A fully known value of the given width.
pub fn Bits::from_uint(val : UInt64, width : Int32) -> Bits {
  Bits::make(width, val, 0UL, 0UL)
}

/// A fully known value of the given width, interpreted as two's complement.
pub fn Bits::from_sint(val : Int64, width : Int32) -> Bits {
  let b = Bits::make(width, val.reinterpret_as_uint64(), 0UL, 0UL)
  { width: b.width, val: b.val, unk: b.unk, zed: b.zed, signed: true }
}

/// The 32-bit integer literal a Verilog unsized decimal produces.
pub fn Bits::from_int(val : Int32) -> Bits {
  Bits::make(32, val.reinterpret_as_uint().to_uint64(), 0UL, 0UL)
}

/// All bits unknown.
pub fn Bits::all_x(width : Int32) -> Bits {
  Bits::make(width, 0UL, mask_of(width), 0UL)
}

/// All bits high impedance.
pub fn Bits::all_z(width : Int32) -> Bits {
  Bits::make(width, 0UL, mask_of(width), mask_of(width))
}

/// Zero of the given width.
pub fn Bits::zero(width : Int32) -> Bits {
  Bits::make(width, 0UL, 0UL, 0UL)
}

/// One of the given width.
pub fn Bits::one(width : Int32) -> Bits {
  Bits::make(width, 1UL, 0UL, 0UL)
}

/// A single-bit value.
pub fn Bits::from_bool(b : Bool) -> Bits {
  Bits::from_uint(if b { 1UL } else { 0UL }, 1)
}

/// True when every bit is 0 or 1.
pub fn Bits::is_known(self : Bits) -> Bool {
  self.unk == 0UL
}

/// True when at least one bit is high impedance.
pub fn Bits::has_z(self : Bits) -> Bool {
  self.zed != 0UL
}

/// True when the value equals zero.
pub fn Bits::is_zero(self : Bits) -> Bool {
  self.is_known() && self.val == 0UL
}

/// True when the value has exactly one bit set and no unknown bits.
pub fn Bits::is_power_of_two(self : Bits) -> Bool {
  self.is_known() &&
  (self.val != 0UL) &&
  ((self.val & (self.val - 1UL)) == 0UL)
}

/// Logic value of bit `i`.
pub fn Bits::bit_at(self : Bits, i : Int32) -> Logic {
  if i < 0 || i >= self.width {
    X
  } else {
    let m = 1UL << i
    if (self.zed & m) != 0UL {
      Z
    } else if (self.unk & m) != 0UL {
      X
    } else if (self.val & m) != 0UL {
      One
    } else {
      Zero
    }
  }
}

/// Zero-extend or truncate to `width`, zero-extending unless `signed`.
pub fn Bits::resize(self : Bits, width : Int32) -> Bits {
  let b = if width > self.width && self.signed {
    let hi = mask_of(width) & n64(mask_of(self.width))
    if self.is_known() {
      if (self.val & (1UL << (self.width - 1))) != 0UL {
        Bits::make(width, self.val | hi, 0UL, 0UL)
      } else {
        Bits::make(width, self.val, 0UL, 0UL)
      }
    } else {
      Bits::make(width, self.val, self.unk | hi, self.zed)
    }
  } else {
    Bits::make(width, self.val, self.unk, self.zed)
  }
  { width: b.width, val: b.val, unk: b.unk, zed: b.zed, signed: self.signed }
}

/// Same bits, different signedness flag.
pub fn Bits::with_signed(self : Bits, signed : Bool) -> Bits {
  {
    width: self.width,
    val: self.val,
    unk: self.unk,
    zed: self.zed,
    signed: signed,
  }
}

/// Drop the signedness flag (Verilog `$unsigned`).
pub fn Bits::as_unsigned(self : Bits) -> Bits {
  self.with_signed(false)
}

/// Add the signedness flag (Verilog `$signed`).
pub fn Bits::as_signed(self : Bits) -> Bits {
  self.with_signed(true)
}

/// Worst common width used by binary operators.
pub fn max_width(a : Bits, b : Bits) -> Int32 {
  if a.width > b.width {
    a.width
  } else {
    b.width
  }
}

/// Bitwise AND with four-state semantics.
pub fn Bits::band(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  let one = known_ones(a) & known_ones(b)
  let zero = known_zeros(a) | known_zeros(b)
  Bits::make(w, one, n64(one | zero) & mask_of(w), 0UL)
}

/// Bitwise OR with four-state semantics.
pub fn Bits::bor(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  let one = known_ones(a) | known_ones(b)
  let zero = known_zeros(a) & known_zeros(b)
  Bits::make(w, one, n64(one | zero) & mask_of(w), 0UL)
}

/// Bitwise XOR with four-state semantics.
pub fn Bits::bxor(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  let known = n64(a.unk | b.unk) & mask_of(w)
  Bits::make(w, (a.val ^ b.val) & known, n64(known) & mask_of(w), 0UL)
}

/// Bitwise XNOR with four-state semantics.
pub fn Bits::bxnor(self : Bits, other : Bits) -> Bits {
  self.bxor(other).bnot()
}

/// Bitwise NOT: 0 and 1 swap, x and z stay unknown.
pub fn Bits::bnot(self : Bits) -> Bits {
  let m = mask_of(self.width)
  Bits::make(self.width, n64(self.val) & n64(self.unk) & m, self.unk, self.zed)
}

/// Two's complement negation.
pub fn Bits::bneg(self : Bits) -> Bits {
  if !self.is_known() {
    return Bits::all_x(self.width)
  }
  Bits::make(self.width, (n64(self.val) + 1UL) & mask_of(self.width), 0UL, 0UL)
}

/// Addition, result width = max operand width.
pub fn Bits::badd(self : Bits, other : Bits) -> Bits {
  if !self.is_known() || !other.is_known() {
    return Bits::all_x(max_width(self, other))
  }
  let w = max_width(self, other)
  let r = Bits::make(w, self.resize(w).val + other.resize(w).val, 0UL, 0UL)
  r.with_signed(self.signed && other.signed)
}

/// Subtraction.
pub fn Bits::bsub(self : Bits, other : Bits) -> Bits {
  if !self.is_known() || !other.is_known() {
    return Bits::all_x(max_width(self, other))
  }
  let w = max_width(self, other)
  let r = Bits::make(w, self.resize(w).val - other.resize(w).val, 0UL, 0UL)
  r.with_signed(self.signed && other.signed)
}

/// Multiplication.
pub fn Bits::bmul(self : Bits, other : Bits) -> Bits {
  if !self.is_known() || !other.is_known() {
    return Bits::all_x(max_width(self, other))
  }
  let w = max_width(self, other)
  let r = Bits::make(w, self.resize(w).val * other.resize(w).val, 0UL, 0UL)
  r.with_signed(self.signed && other.signed)
}

/// Division.  Division by zero yields x, as in Verilog.
pub fn Bits::bdiv(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  if !a.is_known() || !b.is_known() || b.val == 0UL {
    return Bits::all_x(w)
  }
  if a.signed || b.signed {
    Bits::from_sint(signed_value(a, w) / signed_value(b, w), w)
  } else {
    let r = Bits::make(w, a.val / b.val, 0UL, 0UL)
    r.with_signed(a.signed && b.signed)
  }
}

/// Remainder (sign follows the dividend, as in Verilog).
pub fn Bits::bmod(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  if !a.is_known() || !b.is_known() || b.val == 0UL {
    return Bits::all_x(w)
  }
  if a.signed || b.signed {
    Bits::from_sint(signed_value(a, w) % signed_value(b, w), w)
  } else {
    let r = Bits::make(w, a.val % b.val, 0UL, 0UL)
    r.with_signed(a.signed && b.signed)
  }
}

/// Reinterpret a width-`w` value as a signed 64-bit integer.
pub fn signed_value(b : Bits, w : Int32) -> Int64 {
  if w >= 64 {
    b.val.reinterpret_as_int64()
  } else {
    let m = mask_of(w)
    let v = b.val & m
    if (v & (1UL << (w - 1))) != 0UL {
      (v | n64(m)).reinterpret_as_int64()
    } else {
      v.reinterpret_as_int64()
    }
  }
}

/// Left shift; vacated bits become zero.
pub fn Bits::bshl(self : Bits, other : Bits) -> Bits {
  if !other.is_known() {
    return Bits::all_x(self.width)
  }
  let n = other.val
  if n >= 64UL {
    Bits::zero(self.width).with_signed(self.signed)
  } else {
    let s = n.to_int()
    Bits::make(
      self.width,
      (self.val << s) & mask_of(self.width),
      (self.unk << s) & mask_of(self.width),
      (self.zed << s) & mask_of(self.width),
    ).with_signed(self.signed)
  }
}

/// Logical right shift: vacated bits are zero, `x`/`z` shift in from the top.
pub fn Bits::bshr(self : Bits, other : Bits) -> Bits {
  if !other.is_known() {
    return Bits::all_x(self.width)
  }
  let n = other.val
  if n >= 64UL {
    Bits::zero(self.width).with_signed(self.signed)
  } else {
    let s = n.to_int()
    Bits::make(self.width, self.val >> s, self.unk >> s, self.zed >> s)
    .with_signed(self.signed)
  }
}

/// Arithmetic right shift: sign bits fill in when the value is signed.
pub fn Bits::bashr(self : Bits, other : Bits) -> Bits {
  if !self.is_known() {
    return Bits::all_x(self.width)
  }
  if !other.is_known() {
    return Bits::all_x(self.width)
  }
  let s = if other.val >= 64UL { 64 } else { other.val.to_int() }
  let w = self.width
  let m = mask_of(w)
  let sign_set = w > 0 && (self.val & (1UL << (w - 1))) != 0UL
  let fill = if self.signed && sign_set { m } else { 0UL }
  let shifted = if s >= 64 { 0UL } else { self.val >> s }
  let keep = if s >= 64 { 0UL } else { m >> s }
  Bits::make(w, (shifted | (fill & n64(keep))) & m, 0UL, 0UL).with_signed(self.signed)
}

/// Equality: 1 when equal, x when any compared bit is unknown.
pub fn Bits::beq(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  if !a.is_known() || !b.is_known() {
    Bits::all_x(1)
  } else {
    Bits::from_bool((a.val & mask_of(w)) == (b.val & mask_of(w)))
  }
}

/// Inequality.
pub fn Bits::bne(self : Bits, other : Bits) -> Bits {
  let r = self.beq(other)
  if r.is_known() {
    Bits::from_bool(r.val == 0UL)
  } else {
    r
  }
}

/// Case equality (`===`): x and z compare structurally.
pub fn Bits::bcase_eq(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  Bits::from_bool(a.val == b.val && a.unk == b.unk && a.zed == b.zed)
}

/// Case inequality (`!==`).
pub fn Bits::bcase_ne(self : Bits, other : Bits) -> Bits {
  let r = self.bcase_eq(other)
  Bits::from_bool(r.val == 0UL)
}

/// Unsigned (or signed when either side is signed) less-than.
pub fn Bits::blt(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  if !a.is_known() || !b.is_known() {
    Bits::all_x(1)
  } else if a.signed || b.signed {
    Bits::from_bool(signed_value(a, w) < signed_value(b, w))
  } else {
    Bits::from_bool(a.val < b.val)
  }
}

/// Less-than-or-equal.
pub fn Bits::ble(self : Bits, other : Bits) -> Bits {
  let r = self.bgt(other)
  if r.is_known() {
    Bits::from_bool(r.val == 0UL)
  } else {
    r
  }
}

/// Greater-than.
pub fn Bits::bgt(self : Bits, other : Bits) -> Bits {
  let w = max_width(self, other)
  let a = self.resize(w)
  let b = other.resize(w)
  if !a.is_known() || !b.is_known() {
    Bits::all_x(1)
  } else if a.signed || b.signed {
    Bits::from_bool(signed_value(a, w) > signed_value(b, w))
  } else {
    Bits::from_bool(a.val > b.val)
  }
}

/// Greater-than-or-equal.
pub fn Bits::bge(self : Bits, other : Bits) -> Bits {
  let r = self.blt(other)
  if r.is_known() {
    Bits::from_bool(r.val == 0UL)
  } else {
    r
  }
}

/// Logical AND (`&&`); a known zero on either side forces 0.
pub fn Bits::land(self : Bits, other : Bits) -> Bits {
  let a = self.truth()
  let b = other.truth()
  match (a, b) {
    (Some(false), _) | (_, Some(false)) => Bits::from_bool(false)
    (Some(true), Some(true)) => Bits::from_bool(true)
    _ => Bits::all_x(1)
  }
}

/// Logical OR (`||`).
pub fn Bits::lor(self : Bits, other : Bits) -> Bits {
  let a = self.truth()
  let b = other.truth()
  match (a, b) {
    (Some(true), _) | (_, Some(true)) => Bits::from_bool(true)
    (Some(false), Some(false)) => Bits::from_bool(false)
    _ => Bits::all_x(1)
  }
}

/// Logical NOT (`!`).
pub fn Bits::lnot(self : Bits) -> Bits {
  match self.truth() {
    Some(true) => Bits::from_bool(false)
    Some(false) => Bits::from_bool(true)
    None => Bits::all_x(1)
  }
}

/// Truthiness: `None` when the value contains x/z.
pub fn Bits::truth(self : Bits) -> Bool? {
  if !self.is_known() {
    None
  } else {
    Some(self.val != 0UL)
  }
}

/// Concatenate, `self` becoming the high part.
pub fn Bits::concat(self : Bits, low : Bits) -> Bits {
  let w = self.width + low.width
  if w > 64 {
    // Over-wide results are reported by the caller; clamp defensively.
    return Bits::all_x(64)
  }
  let hi = self.val << low.width
  let hu = self.unk << low.width
  let hz = self.zed << low.width
  Bits::make(w, hi | low.val, hu | low.unk, hz | low.zed)
}

/// Replicate `self` `count` times; `self` is the low copy.
pub fn Bits::replicate(self : Bits, count : Int32) -> Bits {
  if count <= 0 {
    return Bits::zero(0)
  }
  let mut acc = self
  for _i in 1..<count {
    acc = acc.concat(self)
  }
  acc
}

/// Extract bit `i` as a one-bit value.
pub fn Bits::bit_sel(self : Bits, i : Int32) -> Bits {
  if i < 0 || i >= self.width {
    Bits::all_x(1)
  } else {
    match self.bit_at(i) {
      Zero => Bits::zero(1)
      One => Bits::one(1)
      X => Bits::all_x(1)
      Z => Bits::all_z(1)
    }
  }
}

/// Extract the inclusive part-select `[hi:lo]`.  Out-of-range indices yield x.
pub fn Bits::part_sel(self : Bits, hi : Int32, lo : Int32) -> Bits {
  let h = if hi > lo { hi } else { lo }
  let l = if hi > lo { lo } else { hi }
  if l < 0 || h >= self.width {
    return Bits::all_x(h - l + 1)
  }
  let n = h - l + 1
  let m = mask_of(n)
  Bits::make(n, (self.val >> l) & m, (self.unk >> l) & m, (self.zed >> l) & m)
}

/// Replace the inclusive part-select `[hi:lo]` of `self` with `value`.
pub fn Bits::set_part(self : Bits, hi : Int32, lo : Int32, value : Bits) -> Bits {
  let h = if hi > lo { hi } else { lo }
  let l = if hi > lo { lo } else { hi }
  let n = h - l + 1
  let m = mask_of(n) << l
  let v = value.resize(n)
  let keep_v = self.val & n64(m)
  let keep_u = self.unk & n64(m)
  let keep_z = self.zed & n64(m)
  Bits::make(
    self.width,
    keep_v | ((v.val << l) & m),
    keep_u | ((v.unk << l) & m),
    keep_z | ((v.zed << l) & m),
  )
}

/// Reduction AND: 0 if any bit is 0, x if any bit is x/z, else 1.
pub fn Bits::red_and(self : Bits) -> Bits {
  if known_zeros(self) != 0UL {
    Bits::zero(1)
  } else if !self.is_known() {
    Bits::all_x(1)
  } else {
    Bits::one(1)
  }
}

/// Reduction OR: 1 if any bit is 1, x if any bit is x/z, else 0.
pub fn Bits::red_or(self : Bits) -> Bits {
  if known_ones(self) != 0UL {
    Bits::one(1)
  } else if !self.is_known() {
    Bits::all_x(1)
  } else {
    Bits::zero(1)
  }
}

/// Reduction XOR: parity of the known bits, x if any bit is x/z.
pub fn Bits::red_xor(self : Bits) -> Bits {
  if !self.is_known() {
    Bits::all_x(1)
  } else {
    let mut parity = false
    let mut v = self.val & mask_of(self.width)
    while v != 0UL {
      parity = !parity
      v = v & (v - 1UL)
    }
    Bits::from_bool(parity)
  }
}

/// Numeric value as `UInt64`; unknown bits are treated as zero.
pub fn Bits::to_uint64(self : Bits) -> UInt64 {
  self.val & mask_of(self.width)
}

/// Numeric value as `Int64`, sign-extended according to the `signed` flag.
pub fn Bits::to_int64(self : Bits) -> Int64 {
  if self.signed {
    signed_value(self, self.width)
  } else {
    (self.val & mask_of(self.width)).reinterpret_as_int64()
  }
}

/// Equality of representation, ignoring the signedness flag.
pub fn Bits::same_bits(self : Bits, other : Bits) -> Bool {
  self.width == other.width &&
  self.val == other.val &&
  self.unk == other.unk &&
  self.zed == other.zed
}

/// Exponentiation by squaring; the result width is the wider operand.
pub fn Bits::bpow(self : Bits, other : Bits) -> Bits {
  let w = if self.width >= other.width { self.width } else { other.width }
  if !self.is_known() || !other.is_known() {
    return Bits::all_x(w)
  }
  let mut base = self.resize(w)
  let mut acc = Bits::from_uint(1UL, w)
  let mut n = other.to_uint64()
  while n > 0UL {
    if (n & 1UL) == 1UL {
      acc = acc.bmul(base)
    }
    base = base.bmul(base)
    n = n >> 1
  }
  acc
}

/// Value as a 32-bit integer, truncating.
pub fn Bits::to_int(self : Bits) -> Int32 {
  (self.val & mask_of(32)).reinterpret_as_int64().to_int()
}

/// A `width`-bit value with every bit set to `l`.
pub fn Bits::from_logic(l : Logic, width : Int32) -> Bits {
  let w = if width < 1 { 1 } else { width }
  let m = mask_of(w)
  match l {
    Zero => Bits::make(w, 0UL, 0UL, 0UL)
    One => Bits::make(w, m, 0UL, 0UL)
    Z => Bits::make(w, 0UL, 0UL, m)
    X => Bits::make(w, 0UL, m, 0UL)
  }
}

/// Pack a string into 8 bits per character, first character in the high bits.
pub fn Bits::from_bytes_string(s : String) -> Bits {
  let mut out = Bits::zero(0)
  let mut i = 0
  while i < s.length() {
    let c = match s.get_char(i) {
      Some(ch) => ch
      None => '\u{0}'
    }
    out = out.concat(Bits::from_uint(c.to_int().reinterpret_as_uint().to_uint64(), 8))
    i = i + 1
  }
  out
}
