require 'dry-validation'

module Mulukhiya
  class UserConfigCommandContract < Dry::Validation::Contract
    params do
      optional(:command).value(:string)
      optional(:tags)
      optional(:growi)
      optional(:dropbox)
      optional(:notify)
      optional(:amazon)
    end

    rule(:command) do
      key.failure('/command が正しくありません。') unless value == 'user_config'
    end

    rule(:tags) do
      if value.nil?
      elsif value.is_a?(Array)
        value.each do |tag|
          next if tag.is_a?(String)
          key.failure('/tags にタグ化できない要素（数値等）が含まれています。')
        end
      else
        key.failure('/tags が配列ではありません。')
      end
    end

    rule(:growi) do
      if value.nil?
      elsif value.is_a?(Hash)
        if value['url'].nil?
        elsif Ginseng::URI.parse(value['url']).absolute?
        else
          key.failure('/growi/url が正しいURLではありません。')
        end
        if value['token'].nil?
        elsif value['token'].is_a?(String)
        else
          key.failure('/growi/token が文字列ではありません。')
        end
      else
        key.failure('/growi がハッシュではありません。')
      end
    end

    rule(:dropbox) do
      if value.nil?
      elsif value.is_a?(Hash)
        if value['token'].nil?
        elsif value['token'].is_a?(String)
        else
          key.failure('/dropbox/token が文字列ではありません。')
        end
      else
        key.failure('/dropbox がハッシュではありません。')
      end
    end

    rule(:notify) do
      if value.nil?
      elsif value.is_a?(Hash)
        key.failure('/notify/verbose が真ではありません。') unless value['verbose'].is_a?(TrueClass)
      else
        key.failure('/notify がハッシュではありません。')
      end
    end

    rule(:amazon) do
      if value.nil?
      elsif value.is_a?(Hash)
        key.failure('/amazon/affiliate が偽ではありません。') unless value['affiliate'].is_a?(FalseClass)
      else
        key.failure('/amazon がハッシュではありません。')
      end
    end
  end
end
