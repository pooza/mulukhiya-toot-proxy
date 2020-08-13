module Mulukhiya
  class MastodonAuthContract < Contract
    params do
      required(:code).value(:string)
    end

    rule(:code) do
      key.failure('空欄です。') if value.length.zero?
    end
  end
end
