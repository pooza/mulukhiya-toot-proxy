module Mulukhiya
  module Mastodon
    class Status < Sequel::Model(:statuses)
      include Package
      include StatusMethods
      include SNSMethods
      one_to_many :attachment
      one_to_one :poll
      many_to_one :account

      def acct
        return account.acct
      end

      alias local? local

      def public?
        return visibility.zero?
      end

      def updatable_by?(target)
        target = Account[target] unless target.is_a?(Account)
        return account&.id == target&.id
      end

      alias attachments attachment

      def uri
        @uri ||= create_status_uri(self[:url] || self[:uri])
        return @uri
      end

      def public_uri
        @public_uri ||= self.class.create_uri(:public, {username: account.username, id:})
        return @public_uri
      end

      def service
        @service ||= MastodonService.new
        return @service
      end

      def visibility_name
        return self.class.visibility_names[visibility]
      end

      def date
        return Time.parse(created_at.strftime('%Y/%m/%d %H:%M:%S GMT')).getlocal
      end

      def to_md
        return uri.to_md
      rescue => e
        e.log
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def self.create_uri(type, params)
        service = MastodonService.new
        params[:id] ||= params[:status_id]
        case type.to_sym
        in :public
          return service.create_uri("/@#{params[:username]}/#{params[:id]}")
        in :webui
          return service.create_uri("/mulukhiya/app/status/#{params[:id]}")
        end
      end

      def self.visibility_names
        return [:public, :unlisted, :private, :direct].map {|v| TootParser.visibility_name(v)}
      end
    end
  end
end
