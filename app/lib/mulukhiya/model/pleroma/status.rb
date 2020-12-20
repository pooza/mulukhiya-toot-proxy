module Mulukhiya
  module Pleroma
    class Status
      include Package
      include StatusMethods
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def data
        unless @data
          @data = PleromaService.new.fetch_status(id).parsed_response
          @data.deep_symbolize_keys!
        end
        return @data
      end

      def acct
        unless @acct
          @acct = Acct.new(data[:account][:acct])
          @acct.host ||= Environment.domain_name
        end
        return @acct
      end

      def local?
        return acct.host == Environment.domain_name
      end

      def account
        @account ||= Account.get(acct: acct)
        return @account
      end

      def text
        return data[:content]
      end

      def uri
        @uri ||= TootURI.parse(data[:url])
        return @uri
      end

      alias public_uri uri

      def attachments
        return data[:media_attachments]
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

      def to_h
        @hash ||= data.deep_compact
        return @hash
      end

      def self.[](id)
        return Status.new(id)
      end
    end
  end
end
