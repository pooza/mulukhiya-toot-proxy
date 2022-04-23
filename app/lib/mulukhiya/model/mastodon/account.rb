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
        return values.deep_symbolize_keys.merge(
          is_admin: admin?,
          is_moderator: moderator?,
          is_info_bot: info?,
          is_test_bot: test?,
          display_name:,
        ).except(
          :private_key,
          :public_key,
        ).compact
      end

      def display_name
        return values[:display_name] if values[:display_name].present?
        return acct.to_s
      end

      def domain
        return values[:domain] || Environment.domain_name
      end

      alias host domain

      def statuses(params = {})
        params[:limit] ||= config['/webui/status/timeline/limit']
        params[:page] ||= 1
        rows = Postgres.instance.exec('statuses', params.merge(id:))
        return rows.filter_map {|v| Status[v[:id]]}.map(&:to_h)
      end

      def recent_status
        return nil unless row = Postgres.instance.exec('recent_toot', {id:}).first
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
        case key
        in {token: token}
          return nil unless token = (key[:token].decrypt rescue key[:token])
          return nil unless row = Postgres.instance.exec('token_owner', {token:})&.first
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
