module Mulukhiya
  class MisskeyAuthContract < Contract
    params do
      required(:code).value(:string)
    end

    rule(:code) do
      key.failure('空欄です。') if value.empty?
    end
  end
end
