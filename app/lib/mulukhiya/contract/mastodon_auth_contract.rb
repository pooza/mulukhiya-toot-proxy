require 'dry-validation'

module Mulukhiya
  class MastodonAuthContract < Dry::Validation::Contract
    params do
      optional(:code).value(:string)
    end

    rule(:code) do
      key.failure('認証コードが空欄です。') unless value.present?
    end
  end
end
