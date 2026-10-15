module Mulukhiya
  module Pleroma
    # ⚠ **DB ではなく API で読む**（v4 と同じ）。Akkoma の投稿は `objects` / `activities` の
    # JSON にあり、Mastodon の `statuses` のような表が無い。
    class Status
      include Package
      include StatusMethods
      include SNSMethods

      attr_reader :id

      def initialize(id)
        @id = id
      end

      def service
        @service ||= PleromaService.new
        return @service
      end

      def values
        return data
      end

      def acct
        unless @acct
          name = data.dig(:account, :acct)
          @acct = Acct.new("@#{name}")
          @acct = Acct.new("@#{name}@#{Environment.domain_name}") unless @acct.host
        end
        return @acct
      end

      def local?
        return acct.host == Environment.domain_name
      end

      def visibility
        return data[:visibility]
      end

      alias visibility_name visibility

      def date
        return Time.parse(data[:created_at]).getlocal
      end

      def account
        @account ||= Account.get(acct:)
        return @account
      end

      def updatable_by?(target)
        target = Account[target] unless target.is_a?(Account)
        return account&.id == target&.id
      end

      def text
        return data[:content]
      end

      def uri
        @uri ||= create_status_uri(data[:url] || data[:uri])
        return @uri
      end

      alias public_uri uri

      def attachments
        return data[:media_attachments] || []
      end

      def self.[](id)
        return new(id)
      end
    end
  end
end
