module Mulukhiya
  module Mastodon
    class Account < Sequel::Model(:accounts)
      include Package
      include AccountMethods
      include SNSMethods
      one_to_one :user
      one_to_many :attachment, key: :account_id
      attr_accessor :token

      def to_h
        unless @hash
          @hash = values.deep_symbolize_keys.merge(
            is_admin: admin?,
            is_moderator: moderator?,
            is_info_bot: info?,
            is_test_bot: test?,
            display_name: display_name,
          )
          @hash.delete(:private_key)
          @hash.delete(:public_key)
          @hash.deep_compact!
        end
        return @hash
      end

      def display_name
        return values[:display_name] if values[:display_name].present?
        return acct.to_s
      end

      def domain
        return values[:domain] || Environment.domain_name
      end

      alias host domain

      def recent_status
        rows = Postgres.instance.exec('recent_toot', {id: id})
        return Status[rows.first['id']] if rows.present?
        return nil
      end

      alias recent_toot recent_status

      def featured_tags
        response = service.fetch_featured_tags(id)
        return TagContainer.new(response.parsed_response.map {|v| v['name']})
      rescue => e
        logger.error(error: e, acct: acct.to_s)
        return TagContainer.new
      end

      def fields
        return JSON.parse(values[:fields] || '[]')
      rescue => e
        logger.error(error: e, acct: acct.to_s)
        return []
      end

      def bio
        return note || ''
      end

      alias attachments attachment

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

      def self.get(key)
        if key.key?(:token)
          return nil unless token = (key[:token].decrypt rescue key[:token])
          account = Postgres.instance.exec('token_owner', {token: token})&.first
          account = Account[account[:id]]
          account.token = token
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
