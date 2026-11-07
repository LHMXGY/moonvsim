// Textual rendering of four-state values.

fn hex_digit_char(d : UInt64) -> Char {
  if d < 10UL {
    (48 + d.to_int()).unsafe_to_char()
  } else {
    (87 + d.to_int()).unsafe_to_char()
  }
}

/// Binary digits, MSB first, exactly `width` characters.
pub fn Bits::to_bin_string(self : Bits) -> String {
  let sb = StringBuilder()
  let mut i = self.width - 1
  while i >= 0 {
    sb.write_char(self.bit_at(i).to_char())
    i = i - 1
  }
  sb.to_string()
}

/// Octal digits, MSB first (unknown groups render as `x`/`z`).
pub fn Bits::to_oct_string(self : Bits) -> String {
  let sb = StringBuilder()
  let ndigits = (self.width + 2) / 3
  let mut i = ndigits - 1
  while i >= 0 {
    let mut acc = 0UL
    let mut unknown = 0UL
    let mut zed = 0UL
    let mut b = 0
    while b < 3 {
      let idx = i * 3 + b
      if idx < self.width {
        match self.bit_at(idx) {
          Zero => ()
          One => acc = acc | (1UL << b)
          X => unknown = unknown | (1UL << b)
          Z => zed = zed | (1UL << b)
        }
      }
      b = b + 1
    }
    if zed != 0UL {
      sb.write_char('z')
    } else if unknown != 0UL {
      sb.write_char('x')
    } else {
      sb.write_char((48 + acc.to_int()).unsafe_to_char())
    }
    i = i - 1
  }
  sb.to_string()
}

/// Hex digits, MSB first (unknown groups render as `x`/`z`).
pub fn Bits::to_hex_string(self : Bits) -> String {
  let sb = StringBuilder()
  let ndigits = (self.width + 3) / 4
  let mut i = ndigits - 1
  while i >= 0 {
    let mut acc = 0UL
    let mut unknown = 0UL
    let mut zed = 0UL
    let mut b = 0
    while b < 4 {
      let idx = i * 4 + b
      if idx < self.width {
        match self.bit_at(idx) {
          Zero => ()
          One => acc = acc | (1UL << b)
          X => unknown = unknown | (1UL << b)
          Z => zed = zed | (1UL << b)
        }
      }
      b = b + 1
    }
    if zed != 0UL {
      sb.write_char('z')
    } else if unknown != 0UL {
      sb.write_char('x')
    } else {
      sb.write_char(hex_digit_char(acc))
    }
    i = i - 1
  }
  sb.to_string()
}

/// Decimal rendering: `x` when any bit is unknown, signed when the value is
/// signed, unsigned otherwise.
pub fn Bits::to_dec_string(self : Bits) -> String {
  if !self.is_known() {
    "x"
  } else if self.signed {
    self.to_int64().to_string()
  } else {
    self.to_uint64().to_string()
  }
}

/// Render using a Verilog format specifier body (`d`, `h`, `b`, `o`, `x`, `s`).
pub fn Bits::format(
  self : Bits,
  spec : Char,
  width : Int32,
  zero_pad : Bool,
) -> String {
  let text = match spec {
    'd' | 'D' => self.to_dec_string()
    'h' | 'H' | 'x' | 'X' => self.to_hex_string()
    'b' | 'B' => self.to_bin_string()
    'o' | 'O' => self.to_oct_string()
    'c' | 'C' =>
      if self.is_known() {
        let code = self.to_uint64().to_int()
        if code >= 0 && code < 0x110000 {
          code.unsafe_to_char().to_string()
        } else {
          "?"
        }
      } else {
        "x"
      }
    's' | 'S' =>
      if self.is_known() {
        // Verilog strings are byte strings; render printable ASCII and drop NULs.
        let sb = StringBuilder()
        let mut shift = (self.width / 8) * 8 - 8
        while shift >= 0 {
          let byte = (self.val >> shift).to_int() & 0xFF
          if byte != 0 {
            sb.write_char(byte.unsafe_to_char())
          }
          shift = shift - 8
        }
        sb.to_string()
      } else {
        "x"
      }
    _ => self.to_dec_string()
  }
  pad_left(text, width, zero_pad)
}

/// Pad `text` on the left to `width` characters.
pub fn pad_left(text : String, width : Int32, zero_pad : Bool) -> String {
  if width <= 0 || text.length() >= width {
    return text
  }
  let sb = StringBuilder()
  let pad_char = if zero_pad { '0' } else { ' ' }
  let mut i = 0
  while i < width - text.length() {
    sb.write_char(pad_char)
    i = i + 1
  }
  sb.write_string(text)
  sb.to_string()
}

/// Render with left padding by spaces.
pub fn pad_left_spaces(text : String, width : Int32) -> String {
  pad_left(text, width, false)
}
