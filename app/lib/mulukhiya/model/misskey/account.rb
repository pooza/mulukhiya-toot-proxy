module Mulukhiya
  module Misskey
    class Account < Sequel::Model(:user)
      include Package
      include AccountMethods
      include SNSMethods

      one_to_one :account_profile, key: :userId
      one_to_many :attachment, key: :userId
      many_to_many :roles, left_key: :userId, right_key: :roleId, join_table: :role_assignment

      # Misskey は作成時刻を持たず id (aid) に埋め込むため、最古 id = 最古アカウント。
      # 「設立日」の近似として最古ローカルアカウントの作成日を返す (#4434)。値は不変の
      # ためメモ化する。DB 未接続・不在時は nil。
      def self.founded_at
        return @founded_at if defined?(@founded_at) && @founded_at
        account = where(host: nil).order(:id).first
        return @founded_at = account && MisskeyService.parse_aid(account.id)
      rescue => e
        e.log
        return nil
      end

      def to_h
        return super.except(:token)
      end

      def display_name
        return name if name.present?
        return username
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
          status.to_h.merge(account: {username:, display_name:, acct: acct.to_s})
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

      def followed_tags
        tags = TagContainer.new
        service.antennas.map {|v| v['keywords'].first}.each {|v| tags.merge(v)}
        return tags
      rescue => e
        e.log(acct: acct.to_s)
        return TagContainer.new
      end

      alias attachments attachment

      def admin?
        return true if roles.any?(&:admin?)
        return false
      end

      alias service? isBot

      alias bot? isBot

      alias locked? isLocked

      def self.get(key)
        case key
        in {acct: acct}
          acct = Acct.new(acct.to_s) unless acct.is_a?(Acct)
          return first(username: acct.username, host: acct.domain)
        in {token: token}
          return nil unless token = token.decrypt rescue token
          return first(key) || AccessToken.first(hash: token)&.account
        else
          return first(key)
        end
      end
    end
  end
end
