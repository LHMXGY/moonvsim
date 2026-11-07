// Verilog-2001 tokenizer.

/// Token kinds produced by the lexer.
pub(all) enum TokenKind {
  Ident(String)
  Number(@value.Bits)
  Str(String)
  Punct(String)
  Eof
}

/// A token with its 1-based source position.
pub(all) struct Token {
  kind : TokenKind
  line : Int32
  col : Int32
}

/// Streaming lexer state.
pub(all) struct Lexer {
  src : String
  mut pos : Int32
  mut line : Int32
  mut col : Int32
  errors : Array[String]
}

pub fn Lexer::new(src : String) -> Lexer {
  { src: src, pos: 0, line: 1, col: 1, errors: [] }
}

fn Lexer::peek(self : Lexer) -> Char? {
  self.src.get_char(self.pos)
}

fn Lexer::peek_at(self : Lexer, off : Int32) -> Char? {
  self.src.get_char(self.pos + off)
}

fn Lexer::bump(self : Lexer) -> Unit {
  match self.src.get_char(self.pos) {
    None => ()
    Some(ch) => {
      self.pos = self.pos + 1
      if ch == '\n' {
        self.line = self.line + 1
        self.col = 1
      } else {
        self.col = self.col + 1
      }
    }
  }
}

fn Lexer::error(self : Lexer, msg : String) -> Unit {
  self.errors.push("[lex] line \{self.line}:\{self.col}: \{msg}")
}

fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\u{000B}'
}

fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

fn is_ident_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  c == '_' ||
  c == '$'
}

fn is_ident_char(c : Char) -> Bool {
  is_ident_start(c) || is_digit(c)
}

fn char_to_digit(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 87
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 55
  } else {
    -1
  }
}

/// Punctuation operators, longest first so prefix matching picks the longest.
let puncts : Array[String] = [
  "===", "!==", ">>>", "<<<", "==", "!=", "&&", "||", "<=", ">=", "<<", ">>",
  "~&", "~|", "~^", "^~", "+:", "-:", "**", "->", "+", "-", "*", "/", "%", "(",
  ")", "[", "]", "{", "}", ";", ":", ",", ".", "#", "@", "?", "=", "<", ">",
  "!", "&", "|", "^", "~",
]

fn Lexer::skip_trivia(self : Lexer) -> Unit {
  let mut again = true
  while again {
    again = false
    match self.peek() {
      Some(c) =>
        if is_space(c) {
          self.bump()
          again = true
        }
      None => ()
    }
    if again {
      continue
    }
    if self.peek() == Some('/') {
      match self.peek_at(1) {
        Some('/') => {
          while self.peek() != Some('\n') && self.peek() is Some(_) {
            self.bump()
          }
          again = true
        }
        Some('*') => {
          self.bump()
          self.bump()
          let mut closed = false
          while !closed {
            match self.peek() {
              None => {
                self.error("unterminated block comment")
                closed = true
              }
              Some('*') =>
                if self.peek_at(1) == Some('/') {
                  self.bump()
                  self.bump()
                  closed = true
                } else {
                  self.bump()
                }
              Some(_) => self.bump()
            }
          }
          again = true
        }
        _ => ()
      }
    }
  }
}

fn Lexer::read_ident(self : Lexer) -> String {
  let sb = StringBuilder()
  if self.peek() == Some('\\') {
    // Escaped identifier: everything up to whitespace.
    self.bump()
    let mut go = true
    while go {
      match self.peek() {
        Some(c) =>
          if is_space(c) {
            go = false
          } else {
            sb.write_char(c)
            self.bump()
          }
        None => go = false
      }
    }
  } else {
    let mut go = true
    while go {
      match self.peek() {
        Some(c) =>
          if is_ident_char(c) {
            sb.write_char(c)
            self.bump()
          } else {
            go = false
          }
        None => go = false
      }
    }
  }
  sb.to_string()
}

fn Lexer::read_string(self : Lexer) -> String {
  self.bump() // opening quote
  let sb = StringBuilder()
  let mut go = true
  while go {
    match self.peek() {
      Some('"') => {
        self.bump()
        go = false
      }
      Some('\\') => {
        self.bump()
        match self.peek() {
          Some('n') => sb.write_char('\n')
          Some('t') => sb.write_char('\t')
          Some('r') => sb.write_char('\r')
          Some('0') => sb.write_char('\u{0000}')
          Some(c) => sb.write_char(c)
          None => ()
        }
        self.bump()
      }
      Some(c) => {
        sb.write_char(c)
        self.bump()
      }
      None => {
        self.error("unterminated string")
        go = false
      }
    }
  }
  sb.to_string()
}

fn parse_uint_text(s : String) -> UInt64 {
  let mut v = 0UL
  let mut i = 0
  while i < s.length() {
    let c = s.get_char(i).unwrap()
    if is_digit(c) {
      v = v * 10UL + (c.to_int() - 48).to_uint64()
    }
    i = i + 1
  }
  v
}

/// Build a value from base-`base` digits, honouring x/z/? digits.
fn build_based(digits : String, base : Int32, width : Int32) -> @value.Bits {
  let per = if base == 16 {
    4
  } else if base == 8 {
    3
  } else {
    1
  }
  let w = if width > 0 { width } else { 32 }
  if base == 10 {
    let mut has_x = false
    let mut has_z = false
    let mut v = 0UL
    let mut i = 0
    while i < digits.length() {
      let c = digits.get_char(i).unwrap()
      match c {
        'x' | 'X' => has_x = true
        'z' | 'Z' | '?' => has_z = true
        _ =>
          if is_digit(c) {
            v = v * 10UL + (c.to_int() - 48).to_uint64()
          }
      }
      i = i + 1
    }
    if has_x {
      @value.Bits::all_x(w)
    } else if has_z {
      @value.Bits::all_z(w)
    } else {
      @value.Bits::from_uint(v, w)
    }
  } else {
    let mut val = 0UL
    let mut unk = 0UL
    let mut zed = 0UL
    let mut shift = 0
    let mut i = digits.length() - 1
    while i >= 0 {
      let c = digits.get_char(i).unwrap()
      let d = match c {
        'x' | 'X' => -2
        'z' | 'Z' | '?' => -3
        _ => char_to_digit(c)
      }
      if shift < 64 {
        if d >= 0 {
          val = val | (d.to_uint64() << shift)
        } else if d == -2 {
          unk = unk | (@value.mask_of(per) << shift)
        } else if d == -3 {
          unk = unk | (@value.mask_of(per) << shift)
          zed = zed | (@value.mask_of(per) << shift)
        }
      }
      shift = shift + per
      i = i - 1
    }
    let m = @value.mask_of(w)
    let v = val & m
    let mut u = unk & m
    let mut z = zed & m
    if shift < w {
      // Zero/unknown extension follows the most significant digit.
      let top = if digits.length() > 0 {
        match digits.get_char(0).unwrap() {
          'x' | 'X' => 1
          'z' | 'Z' | '?' => 2
          _ => 0
        }
      } else {
        0
      }
      let hi = m ^ @value.mask_of(if shift > w { w } else { shift })
      if top == 1 {
        u = u | hi
      } else if top == 2 {
        u = u | hi
        z = z | hi
      }
    }
    @value.Bits::make(w, v, u, z)
  }
}

/// Parse a sized or unsized number literal starting at a digit.
fn Lexer::read_number(self : Lexer) -> @value.Bits {
  let sb = StringBuilder()
  let mut have_digit = false
  let mut go = true
  while go {
    match self.peek() {
      Some(c) =>
        if is_digit(c) {
          sb.write_char(c)
          have_digit = true
          self.bump()
        } else if c == '_' && have_digit {
          self.bump()
        } else {
          go = false
        }
      None => go = false
    }
  }
  let size_text = sb.to_string()
  let size = parse_uint_text(size_text).to_int()
  let mut signed = false
  if self.peek() == Some('\'') {
    self.bump()
    if self.peek() == Some('s') || self.peek() == Some('S') {
      signed = true
      self.bump()
    }
    let base = match self.peek() {
      Some('b') | Some('B') => 2
      Some('o') | Some('O') => 8
      Some('d') | Some('D') => 10
      Some('h') | Some('H') => 16
      Some(c) => {
        self.error("invalid base '\{c}' in number literal")
        10
      }
      None => 10
    }
    self.bump()
    let dsb = StringBuilder()
    let mut go2 = true
    while go2 {
      match self.peek() {
        Some(c) =>
          if is_digit(c) ||
            c == '_' ||
            c == 'x' ||
            c == 'X' ||
            c == 'z' ||
            c == 'Z' ||
            c == '?' ||
            (base == 16 && char_to_digit(c) >= 0) {
            if c != '_' {
              dsb.write_char(c)
            }
            self.bump()
          } else {
            go2 = false
          }
        None => go2 = false
      }
    }
    let v = build_based(dsb.to_string(), base, size)
    if signed {
      v.with_signed(true)
    } else {
      v
    }
  } else {
    // Plain unsized decimal, 32 bits wide.
    @value.Bits::from_uint(parse_uint_text(size_text), 32)
  }
}

fn Lexer::starts_base_literal(self : Lexer) -> Bool {
  match self.peek_at(1) {
    Some(c) =>
      c == 'b' ||
      c == 'B' ||
      c == 'o' ||
      c == 'O' ||
      c == 'd' ||
      c == 'D' ||
      c == 'h' ||
      c == 'H' ||
      c == 's' ||
      c == 'S' ||
      is_digit(c)
    None => false
  }
}

fn Lexer::match_punct(self : Lexer) -> String? {
  for p in puncts {
    let mut ok = true
    let mut i = 0
    while i < p.length() {
      if self.peek_at(i) != Some(p.get_char(i).unwrap()) {
        ok = false
        break
      }
      i = i + 1
    }
    if ok {
      let mut k = 0
      while k < p.length() {
        self.bump()
        k = k + 1
      }
      return Some(p)
    }
  }
  None
}

fn Lexer::next_token(self : Lexer) -> Token {
  self.skip_trivia()
  let line = self.line
  let col = self.col
  match self.peek() {
    None => { kind: Eof, line: line, col: col }
    Some(c) =>
      if is_digit(c) || (c == '\'' && self.starts_base_literal()) {
        let v = self.read_number()
        { kind: Number(v), line: line, col: col }
      } else if is_ident_start(c) || c == '\\' {
        let id = self.read_ident()
        { kind: Ident(id), line: line, col: col }
      } else if c == '"' {
        let s = self.read_string()
        { kind: Str(s), line: line, col: col }
      } else {
        match self.match_punct() {
          Some(p) => { kind: Punct(p), line: line, col: col }
          None => {
            self.error("unexpected character '\{c}'")
            self.bump()
            { kind: Punct(c.to_string()), line: line, col: col }
          }
        }
      }
  }
}

/// Tokenize a source string.  Lexical errors are collected, not thrown.
pub fn tokenize(src : String) -> (Array[Token], Array[String]) {
  let lx = Lexer::new(src)
  let toks : Array[Token] = []
  let mut go = true
  while go {
    let t = lx.next_token()
    match t.kind {
      Eof => {
        toks.push(t)
        go = false
      }
      _ => toks.push(t)
    }
  }
  (toks, lx.errors)
}
