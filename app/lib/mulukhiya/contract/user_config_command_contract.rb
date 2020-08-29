module Mulukhiya
  class UserConfigCommandContract < Contract
    json do # rubocop:disable Metrics/BlockLength
      required(:command).value(:string)
      required(:tags).maybe(:array).each(:string)
      required(:webhook).maybe(:hash).schema do
        optional(:token).maybe(:string)
        optional(:visibility).maybe(:string)
      end
      required(:growi).maybe(:hash).schema do
        optional(:url).maybe(:string)
        optional(:token).maybe(:string)
      end
      required(:dropbox).maybe(:hash).schema do
        optional(:token).maybe(:string)
      end
      required(:annict).maybe(:hash).schema do
        optional(:token).maybe(:string)
      end
      required(:twitter).maybe(:hash).schema do
        optional(:token).maybe(:string)
        optional(:secret).maybe(:string)
      end
      required(:notify).maybe(:hash).schema do
        optional(:verbose).maybe(:bool)
        optional(:user_config).maybe(:bool)
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

    def call(values)
      values = values.clone || {}
      values.deep_stringify_keys!
      values['tags'] ||= []
      values['webhook'] ||= {}
      values['growi'] ||= {}
      values['dropbox'] ||= {}
      values['notify'] ||= {}
      values['amazon'] ||= {}
      values['annict'] ||= {}
      values['twitter'] ||= {}
      return super
    end
  end
end
