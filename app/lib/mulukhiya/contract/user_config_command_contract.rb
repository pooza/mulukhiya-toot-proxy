module Mulukhiya
  class UserConfigCommandContract < Contract
    json do
      required(:command).value(:string)
      required(:tags).maybe(:array).each(:string)
      required(:growi).maybe(:hash).schema do
        optional(:url).maybe(:string)
        optional(:token).maybe(:string)
      end
      required(:dropbox).maybe(:hash).schema do
        optional(:token).maybe(:string)
      end
      required(:notify).maybe(:hash).schema do
        optional(:verbose).maybe(:bool)
      end
      required(:amazon).maybe(:hash).schema do
        optional(:affiliate).maybe(:bool)
      end
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'user_config'
    end

    rule(:growi) do
      if value[:url]
        key.failure('URLが正しくありません。') unless Ginseng::URI.parse(value[:url]).absolute?
      end
    end
  end
end
