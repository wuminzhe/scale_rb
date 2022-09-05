# frozen_string_literal: true

# https://www.rubyguides.com/2017/01/read-binary-data/
class String
  def to_bytes
    data = start_with?('0x') ? self[2..] : self
    raise 'Not valid hex string' if data =~ /[^\da-f]+/i

    data = "0#{data}" if data.length.odd?
    data.scan(/../).map(&:hex)
  end
end

class Integer
  def to_bytes
    to_s(16).to_bytes
  end
end

class Array
  def to_hex
    raise 'Not a byte array' unless byte_array?

    reduce('0x') { |hex, byte| hex + byte.to_s(16).rjust(2, '0') }
  end

  def to_bin
    raise 'Not a byte array' unless byte_array?

    reduce('0b') { |bin, byte| bin + byte.to_s(2).rjust(8, '0') }
  end

  def to_utf8
    raise 'Not a byte array' unless byte_array?

    pack('C*').force_encoding('utf-8')
  end

  def to_scale_uint
    reverse.to_hex.to_i(16)
  end

  def flip
    reverse
  end

  def byte_array?
    all? { |e| e >= 0 and e <= 255 }
  end
end
