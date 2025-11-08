module Mulukhiya
  class UserConfigCommandContract < Contract
    json do
      required(:command).value(:string)
      required(:webhook).maybe(:hash).schema do
        optional(:token).maybe(:string)
        optional(:visibility).maybe(:string)
      end
      required(:annict).maybe(:hash).schema do
        optional(:token).maybe(:string)
      end
      required(:notify).maybe(:hash).schema do
        optional(:verbose).maybe(:bool)
      end
      required(:tagging).maybe(:hash).schema do
        required(:user_tags).maybe(:array).each(:string)
        required(:tags).maybe(:hash).schema do
          required(:disabled).maybe(:array).each(:string)
        end
        optional(:minutes).maybe(:integer).value(gt?: 0)
      end
    end

    rule(:command) do
      key.failure('コマンドが正しくありません。') unless value == 'user_config'
    end

    def call(values)
      values = values.deep_stringify_keys || {}
      values['tags'] ||= []
      values['webhook'] ||= {}
      values['notify'] ||= {}
      values['annict'] ||= {}
      values['piefed'] ||= {}
      values['tagging'] ||= {}
      values['tagging']['user_tags'] ||= []
      values['tagging']['tags'] ||= {}
      values['tagging']['tags']['disabled'] ||= []
      return super
    end
  end
end
