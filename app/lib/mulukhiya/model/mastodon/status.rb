module Mulukhiya
  module Mastodon
    class Status < Sequel::Model(:statuses)
      include Package
      include StatusMethods
      include SNSMethods
      one_to_many :attachment
      many_to_one :account

      def acct
        return account.acct
      end

      alias local? local

      def visible?
        return visibility.zero?
      end

      alias attachments attachment

      def uri
        unless @uri
          @uri = TootURI.parse(self[:url] || self[:uri])
          @uri = NoteURI.parse(self[:url] || self[:uri]) unless @uri&.valid?
          @uri = nil unless @uri&.valid?
        end
        return @uri
      end

      def public_uri
        unless @public_uri
          if Environment.mastodon_type?
            service = sns_class.new
          else
            service = MastodonService.new
          end
          @public_uri = service.create_uri("/@#{account.username}/#{id}")
        end
        return @public_uri
      end

      def to_h
        @hash ||= values.deep_symbolize_keys.deep_compact
        return @hash
      end

      def to_md
        return uri.to_md
      rescue => e
        logger.error(error: e)
        template = Template.new('status_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(text).to_md
        template[:url] = uri.to_s
        return template.to_s
      end
    end
  end
end
