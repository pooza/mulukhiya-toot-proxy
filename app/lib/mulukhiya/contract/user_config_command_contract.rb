require 'dry-validation'

module Mulukhiya
  class UserConfigCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:tags)
      optional(:growi)
    end

    rule(:command) do
      key.failure('command: が正しくありません。') unless value == 'user_config'
    end

    rule(:tags) do
      if value.is_a?(Array)
        value.each do |tag|
          next if tag.is_a?(String)
          key.failure('/tags にタグ化できない要素（数値等）が含まれています。')
        end
      elsif value.nil?
      else
        key.failure('/tags が配列ではありません。')
      end
    end

    rule(:growi) do
      if value.is_a?(Hash)
        if value['url']
          uri = Ginseng::URI.parse(value['url'])
          key.failure('/growi/url が正しいURLではありません。') unless uri.absolute?
        end
      else
        key.failure('/growi がハッシュではありません。')
      end
    end
  end
end
