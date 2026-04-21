module Mulukhiya
  class SwSubscriptionContract < Contract
    params do
      required(:endpoint).value(:string)
      required(:auth).value(:string)
      required(:publickey).value(:string)
      optional(:sendReadMessage).value(:bool)
    end

    rule(:endpoint) do
      key.failure('空欄です。') if value.empty?
      key.failure('https:// で始まる URL を指定してください。') unless value.start_with?('https://')
    end

    rule(:auth) do
      key.failure('空欄です。') if value.empty?
    end

    rule(:publickey) do
      key.failure('空欄です。') if value.empty?
    end
  end
end
