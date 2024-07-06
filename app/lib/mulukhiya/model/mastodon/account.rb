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
        return super.except(:private_key, :public_key)
      end

      def roles
        return [user&.role].compact
      end

      def display_name
        return values[:display_name] if values[:display_name].present?
        return acct.to_s
      end

      def domain
        return values[:domain] || Environment.domain_name
      end

      alias host domain

      def uri
        @uri ||= service.create_uri("/@#{username}")
        return @uri
      end

      def statuses(params = {})
        params[:limit] ||= config['/webui/status/timeline/limit']
        params[:page] ||= 1
        params[:account_id] = id
        return Postgres.exec(:statuses, params).map do |row|
          next unless status = Status[row[:id]]
          status.to_h.merge(account: {username:, display_name:, acct: acct.to_s})
        end
      end

      def recent_status
        return nil unless row = Postgres.first(:recent_toot, {id:})
        return Status[row[:id]]
      end

      alias recent_toot recent_status

      def featured_tags
        response = service.fetch_featured_tags(id)
        return TagContainer.new(response.parsed_response.map {|v| v['name']})
      rescue => e
        e.log(acct: acct.to_s)
        return TagContainer.new
      end

      def followed_tags
        response = service.fetch_followed_tags
        return TagContainer.new(response.parsed_response.map {|v| v['name']})
      rescue => e
        e.log(acct: acct.to_s)
        return TagContainer.new
      end

      def fields
        return JSON.parse(values[:fields] || '[]')
      rescue => e
        e.log(acct: acct.to_s)
        return []
      end

      def bio
        return note || ''
      end

      alias attachments attachment

      def admin?
        return true if user.admin
        return true if roles.any?(&:admin?)
        return false
      end

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      alias locked? locked

      def self.get(key)
        case key
        in {token: token}
          return nil unless token = (key[:token].decrypt rescue key[:token])
          return nil unless row = Postgres.first(:token_owner, {token:})
          return nil unless account = self[row[:id]]
          account.token = token
          return account
        in {acct: acct}
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, domain: acct.domain)
        else
          return first(key)
        end
      end
    end
  end
end
