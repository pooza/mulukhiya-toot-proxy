module Mulukhiya
  module Pleroma
    # Akkoma（Pleroma 系）のアカウント（#4566）。v4 の実装（46c4f4e2^）を戻し、5.x の
    # インタフェースへ合わせた。⚠ テーブルは `users`（Mastodon の `accounts` ではない）、
    # 主キーは uuid。
    class Account < Sequel::Model(:users)
      include Package
      include AccountMethods
      include SNSMethods

      attr_accessor :token

      def to_h
        return super.except(:password_hash, :keys, :magic_key, :email, :confirmation_token,
          :multi_factor_authentication_settings)
      end

      def acct
        unless @acct
          @acct = Acct.new("@#{nickname}")
          @acct = Acct.new("@#{nickname}@#{Environment.domain_name}") unless @acct.host
        end
        return @acct
      end

      def username
        return acct.username
      end

      def display_name
        return name if name.present?
        return acct.to_s
      end

      def host
        return acct.host
      end

      alias domain host

      def uri
        @uri ||= Ginseng::URI.parse(ap_id)
        return @uri
      end

      # ⚠ jsonb。接続の設定によって文字列でも配列でも返る。
      def fields
        value = values[:fields] || '[]'
        value = JSON.parse(value) if value.is_a?(String)
        return value.map(&:to_h)
      rescue => e
        e.log(acct: acct.to_s)
        return []
      end

      def bio
        return values[:bio] || ''
      end

      def featured_tags
        return TagContainer.new
      end

      def followed_tags
        return TagContainer.new
      end

      def attachments
        return []
      end

      def recent_status
        return nil
      end

      alias recent_toot recent_status

      def admin?
        return is_admin == true
      end

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      def locked?
        return is_locked == true
      end

      # ⚠ ローカルは `nickname` だけ、リモートは `user@host` で持っている。
      def self.nickname_of(acct)
        acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
        return acct.username if acct.host.nil? || acct.host == Environment.domain_name
        return acct.to_s.sub(/^@/, '')
      end

      # ⚠ `users` には `domain` / `host` が無い。ローカルかどうかは `local` 列。
      def self.admins
        return where(local: true, is_admin: true).all
      end

      def self.get(key)
        case key
        in {acct: acct}
          return first(nickname: nickname_of(acct))
        in {token: token}
          return nil unless token = token.decrypt rescue token
          return nil unless account = AccessToken.first(token:)&.account
          account.token = token
          return account
        else
          return first(key)
        end
      end
    end
  end
end
