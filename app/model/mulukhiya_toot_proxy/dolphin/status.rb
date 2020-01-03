module MulukhiyaTootProxy
  module Dolphin
    class Status < Sequel::Model(:note)
      def logger
        @logger ||= Logger.new
        return @logger
      end

      def account
        @account ||= Account[userId]
        return @account
      end

      def local?
        return userHost.nil?
      end

      def visible?
        return visibility == 'public'
      end

      def uri
        unless @uri
          if self[:uri].present?
            @uri = MastodonURI.parse(self[:uri])
            @uri = nil unless @uri.id
          else
            @uri = DolphinURI.parse(Config.instance['/dolphin/url'])
            @uri.path = "/notes/#{id}"
          end
        end
        return @uri
      end

      def to_h
        v = values.clone
        v[:uri] ||= uri.to_s
        return v
      end

      def to_md
        return uri.to_md
      rescue => e
        logger.error(e)
        template = Template.new('note_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
