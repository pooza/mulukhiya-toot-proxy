module Mulukhiya
  # Pleroma 系の ID の表記（#4566）。
  #
  # ⚠⚠ **API の ID は DB の主キーと表記が違う。**`users.id` などは uuid で持つが、API は同じ
  # 128 ビットを base62（0-9A-Za-z）で返す（`000001a1-41a5-f9ae-ebad-ac9c5de10000` →
  # `BBRwXUDu0uwfOACCsy`・dev29 の Akkoma 3.20.1 で実測）。
  module FlakeId
    ALPHABET = [*'0'..'9', *'A'..'Z', *'a'..'z'].join.freeze

    def self.encode(uuid)
      number = uuid.to_s.delete('-').to_i(16)
      return ALPHABET[0] if number.zero?
      digits = +''
      while number.positive?
        number, rest = number.divmod(ALPHABET.length)
        digits.prepend(ALPHABET[rest])
      end
      return digits
    end

    def self.decode(id)
      number = id.to_s.each_char.reduce(0) do |sum, char|
        raise ArgumentError, "invalid FlakeId: #{id}" unless value = ALPHABET.index(char)
        (sum * ALPHABET.length) + value
      end
      hex = number.to_s(16).rjust(32, '0')
      return [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join('-')
    end
  end
end
