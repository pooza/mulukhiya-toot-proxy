module Mulukhiya
  module Mastodon
    class Account < Sequel::Model(:accounts)
      include Package
      include AccountMethods
      include SNSMethods

      one_to_one :user
      one_to_many :attachment, key: :account_id
      attr_accessor :token

      # 最古のローカルアカウント作成日を「設立日」の近似として返す (#4434)。
      # ローカル (domain IS NULL) を作成日昇順で 1 件。created_at は GMT 保存なので
      # Status#date / Attachment#date と同じく getlocal してから返し、東経サーバーで
      # 現地深夜作成のアカウントが暦日 1 日前にずれるのを防ぐ (#4437 Codex P2)。
      # 値は不変のためプロセス内でメモ化する。DB 未接続・不在時は nil。
      def self.founded_at
        return @founded_at if defined?(@founded_at) && @founded_at
        return nil unless account = where(domain: nil).order(:created_at).first
        gmt = account.created_at.strftime('%Y/%m/%d %H:%M:%S GMT')
        return @founded_at = Time.parse(gmt).getlocal
      rescue => e
        e.log
        return nil
      end

      def to_h
        return super.except(:private_key, :public_key)
      end

      def roles
        return [user&.role].compact
      end

      def display_name
        return values[:display_name] if values[:display_name].present?
        return username
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
          return nil unless token = key[:token].decrypt rescue key[:token]
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
