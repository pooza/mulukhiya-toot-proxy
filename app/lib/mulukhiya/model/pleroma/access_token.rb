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
        return false if valid_until && valid_until < Time.now
        return true
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
