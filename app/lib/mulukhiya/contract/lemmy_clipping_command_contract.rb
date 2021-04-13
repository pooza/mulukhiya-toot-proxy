module Mulukhiya
  class LemmyClippingCommandContract < Contract
    json do
      required(:command).value(:string)
      required(:url).value(:string)
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'lemmy_clipping'
    end

    rule(:url) do
      key.failure('URLが正しくありません。') unless Ginseng::URI.parse(value).absolute?
    end
  end
end
