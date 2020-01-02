module MulukhiyaTootProxy
  module Dolphin
    class Status < Sequel::Model(:note)
      def account
        @account ||= Environment.account_class[userId]
        return @account
      end

      def local?
        return userHost.nil?
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

      alias to_h values

      def to_md
        return uri.to_md
      rescue
        template = Template.new('note_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
