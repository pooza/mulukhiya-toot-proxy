module Mulukhiya
  module Mastodon
    class Account < Sequel::Model(:accounts)
      include AccountMethods
      attr_accessor :token

      one_to_one :user

      def to_h
        unless @hash
          @hash = values.clone
          @hash.delete(:private_key)
          @hash.delete(:public_key)
          @hash.compact!
        end
        return @hash
      end

      def acct
        @acct ||= Acct.new("@#{username}@#{domain || Environment.domain_name}")
        return @acct
      end

      def recent_status
        rows = Postgres.instance.exec('recent_toot', {id: id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_toot recent_status

      def admin?
        return user.admin
      end

      def moderator?
        return user.moderator
      end

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      alias locked? locked

      def notify_verbose?
        return config['/notify/verbose'] == true
      end

      def disable?(handler_name)
        return true if config["/handler/#{handler_name}/disable"]
        return false
      end

      def tags
        return config['/tags'] || []
      end

      def self.get(key)
        if key.key?(:token)
          return nil if key[:token].nil?
          account = Postgres.instance.exec('token_owner', {token: key[:token]})&.first
          account = Account[account[:id]]
          account.token = key[:token]
          return account
        elsif acct = key[:acct]
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return Account.first(username: acct.username, domain: acct.domain)
        end
        return Account.first(key)
      end
    end
  end
end
