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

      def public?
        return visibility.zero?
      end

      alias attachments attachment

      def uri
        @uri ||= create_status_uri(self[:url] || self[:uri])
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

      def parser
        @parser ||= TootParser.new(text)
        return @parser
      end

      def to_h
        @hash ||= values.deep_symbolize_keys.deep_compact
        return @hash
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
    end
  end
end
