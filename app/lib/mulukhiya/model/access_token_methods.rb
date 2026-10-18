module Mulukhiya
  module AccessTokenMethods
    include SNSMethods

    # 空白だけのトークンも無効とする。`empty?` だと素通りして webhook_digest
    # (空トークンで ConfigError) まで到達する (#4487)。
    def valid?
      return false if to_s.blank?
      return false unless account
      return true
    end

    def webhook_digest
      return Webhook.create_digest(sns_class.new.uri, to_s)
    end

    def scopes_valid?
      return controller_class.oauth_scopes == scopes
    end

    # ⚠⚠ **更新用のトークンは出さない（PR #4844 の Codex P1）。**`GET /config` がこの hash を
    # 返すので、残すとアクセストークンを持つだけで更新用トークンが手に入り、期限切れの後も
    # 新しいトークンを作れる。Akkoma は `refresh_token` を発行する。Mastodon（Doorkeeper）の
    # 表にも同じ列があるので、系統を問わずここで落とす。
    SECRET_COLUMNS = [:refresh_token, :previous_refresh_token].freeze

    def to_h
      @hash ||= values.deep_symbolize_keys.except(*SECRET_COLUMNS).merge(
        account:,
        digest: webhook_digest,
        is_scopes_valid: scopes_valid?,
        scopes: scopes.to_a,
        token: to_s,
      ).compact
      return @hash
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def webhook_entries(&block)
        return enum_for(__method__) unless block
        Postgres.exec(:webhook_tokens)
          .map {|row| row[:id]}
          .lazy
          .filter_map {|id| Environment.access_token_class[id] rescue nil}
          .select(&:valid?)
          .map(&:to_h)
          .each(&block)
      end
    end
  end
end
