module Mulukhiya
  module Pleroma
    class Status
      include Package
      include StatusMethods
      include SNSMethods
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def data
        @data ||= PleromaService.new.fetch_status(id).parsed_response.deep_symbolize_keys
        return @data
      end

      def acct
        unless @acct
          @acct = Acct.new(data.dig(:account, :acct))
          @acct.host ||= Environment.domain_name
        end
        return @acct
      end

      def local?
        return acct.host == Environment.domain_name
      end

      def visibility
        return data[:visibility]
      end

      def account
        @account ||= Account.get(acct: acct)
        return @account
      end

      def text
        return data[:content]
      end

      def uri
        @uri ||= create_status_uri(data[:url])
        return @uri
      end

      alias public_uri uri

      def attachments
        return data[:media_attachments]
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

      def to_h
        @hash ||= data.deep_compact
        return @hash
      end

      def self.[](id)
        return new(id)
      end
    end
  end
end
