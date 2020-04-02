require 'dry-validation'

module Mulukhiya
  class MisskeyAuthContract < Dry::Validation::Contract
    params do
      optional(:token).value(:string)
    end

    rule(:token) do
      key.failure('セッショントークンが空欄です。') unless value.present?
    end
  end
end
