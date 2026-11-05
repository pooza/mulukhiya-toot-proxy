module Mulukhiya
  module Pleroma
    class AccessToken < Sequel::Model(:oauth_tokens)
      include Package
      include AccessTokenMethods
      include SNSMethods

      many_to_one :account, key: :user_id
      many_to_one :application, key: :app_id

      # 空白だけのトークンも無効とする（Mastodon::AccessToken と同じ・#4487）。
      # ⚠ Akkoma の停止（`is_active: false`）は OAuth の行を残すので、ここで弾く。
      def valid?
        return false if to_s.blank?
        return false unless account
        return false unless account.is_active
        return false if expired?
        return true
      end

      # ⚠ `valid_until` は UTC（タイムゾーンなし）。そのまま比べると 9 時間早く切れる (#4864)。
      # webhook の一覧（`webhook_tokens.sql.erb`）は SQL で `now() AT TIME ZONE 'UTC'` と比べるので、ここと揃う。
      def expired?(now = Time.now)
        return false unless expires_at = NaiveTime.utc(valid_until)
        return expires_at < now
      end

      # ⚠ Akkoma 3.20 では配列型（`{read,write}`）。pg_array を読み込んでいない接続では
      # 文字列で返るので、どちらでも受ける（v4 は文字列の正規表現だけだった）。
      def scopes
        value = values[:scopes]
        return value.to_set if value.is_a?(Array)
        return value.to_s.delete('{}').split(',').map(&:strip).reject(&:empty?).to_set
      end

      alias to_s token

      def self.get(key)
        return first(key)
      end
    end
  end
end
