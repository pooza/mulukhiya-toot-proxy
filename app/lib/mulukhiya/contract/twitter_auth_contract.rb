require 'dry-validation'

module Mulukhiya
  class TwitterAuthContract < Dry::Validation::Contract
    params do
      optional(:oauth_token).value(:string)
      optional(:oauth_verifier).value(:string)
    end

    rule(:oauth_token) do
      key.failure('oauth_tokenが空欄です。') unless value.present?
    end

    rule(:oauth_verifier) do
      key.failure('oauth_verifierが空欄です。') unless value.present?
    end
  end
end
