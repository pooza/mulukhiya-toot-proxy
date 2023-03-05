module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      include Package
      include AccountMethods
      include SNSMethods
      one_to_one :account_profile, key: :userId
      one_to_many :attachment, key: :userId

      def to_h
        return super.except(:token)
      end

      def display_name
        return name if name.present?
        return acct.to_s
      end

      def host
        return values[:host] || Environment.domain_name
      end

      alias domain host

      def uri
        unless @uri
          @uri = Ginseng::URI.parse("https://#{host}") if host
          @uri ||= sns_class.new.uri.clone
          @uri.path = "/@#{username}"
        end
        return @uri
      end

      def statuses(params = {})
        params[:limit] ||= config['/webui/status/timeline/limit']
        params[:page] ||= 1
        params[:account_id] = id
        return Postgres.exec(:statuses, params).map do |row|
          next unless status = Status[row[:id]]
          status.to_h.merge(account: row.slice(:username, :display_name))
        end
      end

      def fields
        return JSON.parse(values[:fields] || '[]')
      rescue => e
        e.log(acct: acct.to_s)
        return []
      end

      def bio
        return account_profile.description || ''
      end

      def recent_status
        notes = service.notes(account_id: id)
        note = notes&.first
        return Status[note['id']] if note
        return nil
      end

      alias recent_note recent_status

      def featured_tags
        tags = TagContainer.new
        service.antennas.map {|v| v['keywords'].first}.each {|v| tags.merge(v)}
        return tags
      rescue => e
        e.log(acct: acct.to_s)
        return TagContainer.new
      end

      alias attachments attachment

      alias admin? isRoot

      alias moderator? isRoot

      alias service? isBot

      alias bot? isBot

      alias locked? isLocked

      def self.get(key)
        case key
        in {acct: acct}
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, host: acct.domain)
        in {token: token}
          return nil unless token = (token.decrypt rescue token)
          return first(key) || AccessToken.first(hash: token)&.account
        else
          return first(key)
        end
      end
    end
  end
end
