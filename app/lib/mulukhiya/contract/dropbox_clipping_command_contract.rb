require 'dry-validation'

module Mulukhiya
  class DropboxClippingCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:url).value(:string)
    end

    rule(:command) do
      key.failure('command: が正しくありません。') unless value == 'dropbox_clipping'
    end

    rule(:url) do
      if value.present?
        key.failure('url: が正しくありません。') unless Ginseng::URI.parse(value).absolute?
      else
        key.failure('url: が空欄です。')
      end
    end
  end
end
