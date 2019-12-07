require 'dry-validation'

module MulukhiyaTootProxy
  class GrowiClippingCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:url).value(:string)
    end

    rule(:command) do
      key.failure('コマンド名が正しくありません。') unless value == 'growi_clipping'
    end

    rule(:url) do
      if value.present?
        key.failure('url が正しくありません。') unless URI.parse(value).absolute?
      else
        key.failure('url が空欄です。')
      end
    end
  end
end
