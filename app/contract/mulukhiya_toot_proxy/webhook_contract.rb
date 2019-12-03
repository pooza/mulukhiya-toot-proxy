require 'dry-validation'

module MulukhiyaTootProxy
  class WebhookContract < Dry::Validation::Contract
    params do
      required(:digest).value(:string)
      required(:text).value(:string)
    end

    rule(:digest) do
      key.failure('認証コードが空欄です。') unless value.present?
    end

    rule(:text) do
      key.failure('トゥート本文が空欄です。') unless value.present?
    end
  end
end
