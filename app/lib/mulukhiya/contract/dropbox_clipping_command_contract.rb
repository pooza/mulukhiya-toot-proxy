module Mulukhiya
  class DropboxClippingCommandContract < Contract
    params do
      required(:command).value(:string)
      required(:url).value(:string)
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'dropbox_clipping'
    end

    rule(:url) do
      key.failure('URLが正しくありません。') unless Ginseng::URI.parse(value).absolute?
    end
  end
end
