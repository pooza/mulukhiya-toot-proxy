module MulukhiyaTootProxy
  module Mastodon
    class Status < Sequel::Model(:statuses)
      def account
        @account ||= Environment.account_class[account_id]
        return @account
      end

      def local?
        return local
      end

      def uri
        unless @uri
          @uri = MastodonURI.parse(self[:url] || self[:uri])
          @uri = DolphinURI.parse(self[:url] || self[:uri]) unless @uri.id
          @uri = nil unless @uri.id
        end
        return @uri
      end

      alias to_h values

      def to_md
        return uri.to_md
      rescue
        template = Template.new('toot_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
