# mapping from ISO/TR 11548-1 to "normal" bytes so that we can use the standard
# bit twiddles for simple operations like flipping and rotation
MAP = [
  0, 128, 32, 160, 8, 136, 40, 168, 64, 192, 96, 224, 72, 200, 104, 232,
  16, 144, 48, 176, 24, 152, 56, 184, 80, 208, 112, 240, 88, 216, 120, 248,
  4, 132, 36, 164, 12, 140, 44, 172, 68, 196, 100, 228, 76, 204, 108, 236,
  20, 148, 52, 180, 28, 156, 60, 188, 84, 212, 116, 244, 92, 220, 124, 252,
  2, 130, 34, 162, 10, 138, 42, 170, 66, 194, 98, 226, 74, 202, 106, 234,
  18, 146, 50, 178, 26, 154, 58, 186, 82, 210, 114, 242, 90, 218, 122, 250,
  6, 134, 38, 166, 14, 142, 46, 174, 70, 198, 102, 230, 78, 206, 110, 238,
  22, 150, 54, 182, 30, 158, 62, 190, 86, 214, 118, 246, 94, 222, 126, 254,
  1, 129, 33, 161, 9, 137, 41, 169, 65, 193, 97, 225, 73, 201, 105, 233,
  17, 145, 49, 177, 25, 153, 57, 185, 81, 209, 113, 241, 89, 217, 121, 249,
  5, 133, 37, 165, 13, 141, 45, 173, 69, 197, 101, 229, 77, 205, 109, 237,
  21, 149, 53, 181, 29, 157, 61, 189, 85, 213, 117, 245, 93, 221, 125, 253,
  3, 131, 35, 163, 11, 139, 43, 171, 67, 195, 99, 227, 75, 203, 107, 235,
  19, 147, 51, 179, 27, 155, 59, 187, 83, 211, 115, 243, 91, 219, 123, 251,
  7, 135, 39, 167, 15, 143, 47, 175, 71, 199, 103, 231, 79, 207, 111, 239,
  23, 151, 55, 183, 31, 159, 63, 191, 87, 215, 119, 247, 95, 223, 127, 255,
] of UInt8

# inversion of the above mapping for converting back to ISO/TR 11548-1
UNMAP = MAP.zip(0u8..255).to_h

def flipx(b : UInt8)
  b = (b & 0xF0) >> 4 | (b & 0x0F) << 4
  (b & 0xCC) >> 2 | (b & 0x33) << 2
end

def flipy(b : UInt8)
  (b & 0xAA) >> 1 | (b & 0x55) << 1
end

def invert(b : UInt8)
  b ^ 0xFF
end

def rotate180(b : UInt8)
  b = (b & 0xF0) >> 4 | (b & 0x0F) << 4
  flipy (b & 0xCC) >> 2 | (b & 0x33) << 2
end

SCAN_MASKS = {d: 0x99, dw0: 0xB4, dw1: 0x4B, h: 0xCC, hw: 0xF0, v: 0xAA}
{% for dir, mask in SCAN_MASKS %}
  def scan{{dir}}(b)
    b ^ b & {{mask}}
  end
{% end %}

USAGE = "usage: #{PROGRAM_NAME} OPERATION+ FILE"
abort USAGE unless ARGV.size >= 2

file = ARGV.pop

OPERATIONS = {
  "180", "flipx", "flipy", "invert",
  "scand", "scandw", "scanh", "scanhw", "scanv", "scanvw",
}
unless ARGV.all? { |op| OPERATIONS.includes? op }
  abort "operation must be one or more of: #{OPERATIONS}"
end

abort "No such file: #{file}" unless File.exists? file

converted = File.read_lines(file).map &.chars.map { |c|
  i = c.ord - 0x2800
  abort "found non-Braille character: '#{c}'" unless 0 <= i <= 255
  MAP[i]
}

ARGV.each do |op|
  converted.reverse! if {"flipx", "180"}.includes? op

  converted.map_with_index! { |row, i|
    row.reverse! if {"flipy", "180"}.includes? op

    case op
    when "flipx" ; row.map &->flipx(UInt8)
    when "flipy" ; row.map &->flipy(UInt8)
    when "invert"; row.map &->invert(UInt8)
    when "scand" ; row.map &->scand(UInt8)
    when "scandw"
      row.map_with_index { |b, j| (i + j).even? ? scandw0 b : scandw1 b }
    when "scanh" ; row.map &->scanh(UInt8)
    when "scanhw"; row.map &->scanhw(UInt8)
    when "scanv" ; row.map &->scanv(UInt8)
    when "scanvw"; row.tap { |r| (r.size // 2).times { |i| r[i * 2 + 1] = 0 } }
    else           row.map &->rotate180(UInt8)
    end
  }
end

converted.each do |row|
  puts row.map { |c| (0x2800 + UNMAP[c]).chr }.join
end
