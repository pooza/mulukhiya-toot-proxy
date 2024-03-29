module Mulukhiya
  module Pleroma
    class Account < Sequel::Model(:users)
      include Package
      include AccountMethods
      include SNSMethods
      attr_accessor :token

      def to_h
        return super.except(:password_hash, :keys, :magic_key)
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

      def fields
        return JSON.parse(values[:fields] || '[]').map do |entry|
          entry['value'].sanitize!
          entry
        end
      rescue => e
        e.log(acct: acct.to_s)
        return []
      end

      def recent_status
        return nil unless row = Postgres.first(:recent_toot, {acct:})
        return Status[service.search_status_id(Ginseng::URI.parse(row[:uri]))]
      rescue => e
        e.log(account_id: id)
        return nil
      end

      alias recent_toot recent_status

      alias admin? is_admin

      def service?
        return actor_type == 'Service'
      end

      alias bot? service?

      def locked?
        return false
      end

      def clear_attachments(params = {})
        raise Ginseng::AuthError, 'Only test users can run it' unless test?
        bar = ProgressBar.create(total: deletable_statuses.count)
        deletable_statuses.each do |status|
          service.delete_status(Ginseng::URI.parse(status['uri']))
        rescue => e
          e.log(acct: acct.to_s)
        ensure
          bar&.increment
        end
        bar&.finish
      end

      def self.get(key)
        case key
        in {acct: acct}
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          nickname = acct.username if acct.local?
          nickname ||= acct.to_s.sub(/^@/, '')
          return first(nickname:)
        in {token: token}
          return nil unless token = (token.decrypt rescue token)
          return nil unless account = AccessToken.first(token:)&.account
          account.token = token
          return account
        else
          return first(key)
        end
      end

      private

      def deletable_statuses
        return Postgres.exec(:deletable_statuses, {acct: test_account.acct})
      end
    end
  end
end
