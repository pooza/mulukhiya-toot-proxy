require 'dry-validation'

module Mulukhiya
  class LocalConfigContract < Dry::Validation::Contract
    params do
      optional(:agent)
      optional(:mastodon)
      optional(:misskey)
      optional(:dolphin)
      optional(:postgres)
      optional(:twitter)
    end

    rule(:agent) do
      if value.nil?
        key.failure('/agent 未定義')
      elsif value.is_a?(Hash)
        key.failure('/agent/test/token 未定義') unless value.dig('test', 'token')
        key.failure('/agent/info/token 未定義') unless value.dig('info', 'token')
      end
    end

    rule(:mastodon) do
      if Environment.mastodon? && value.nil?
        key.failure('/mastodon 未定義')
      elsif value.is_a?(Hash)
        if url = value.dig('url')
          key.failure('/mastodon/url 型不正') unless Ginseng::URI.parse(url).absolute?
        else
          key.failure('/mastodon/url 未定義')
        end
      end
    end

    rule(:misskey) do
      if Environment.misskey? && value.nil?
        key.failure('/misskey 未定義')
      elsif value.is_a?(Hash)
        if url = value.dig('url')
          key.failure('/misskey/url 型不正') unless Ginseng::URI.parse(url).absolute?
        else
          key.failure('/misskey/url 未定義')
        end
      end
    end

    rule(:dolphin) do
      if Environment.dolphin? && value.nil?
        key.failure('/dolphin 未定義')
      elsif value.is_a?(Hash)
        if url = value.dig('url')
          key.failure('/dolphin/url 型不正') unless Ginseng::URI.parse(url).absolute?
        else
          key.failure('/dolphin/url 未定義')
        end
      end
    end

    rule(:postgres) do
      if value.nil?
        key.failure('/postgres 未定義')
      elsif value.is_a?(Hash)
        if dsn = value.dig('dsn')
          key.failure('/postgres/dsn 型不正') unless Ginseng::Postgres::DSN.parse(dsn).valid?
        else
          key.failure('/postgres/dsn 未定義')
        end
      end
    end

    rule(:twitter) do
      if value.is_a?(Hash)
        if consumer = value.dig('consumer')
          key.failure('/twitter/consumer/key 未定義') unless consumer['key'].present?
          key.failure('/twitter/consumer/secret 未定義') unless consumer['secret'].present?
        else
          key.failure('/twitter/consumer 未定義')
        end
      end
    end
  end
end
