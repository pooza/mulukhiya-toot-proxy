module Mulukhiya
  module Pleroma
    # ⚠ **DB ではなく API で読む**（v4 と同じ）。Akkoma の投稿は `objects` / `activities` の
    # JSON にあり、Mastodon の `statuses` のような表が無い。
    class Status
      include Package
      include StatusMethods
      include SNSMethods

      attr_reader :id
      attr_writer :service

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

      # ⚠ `content` は描画済みの HTML。Akkoma は素の本文を `pleroma.content` に持つ。
      def text
        return data.dig(:pleroma, :content, :'text/plain') || data[:content]
      end

      def uri
        @uri ||= create_status_uri(data[:url] || data[:uri])
        return @uri
      end

      alias public_uri uri

      # ⚠ ID は API の表記（base62 の FlakeId）。Akkoma の投稿の URL は `/notice/<ID>`。
      def self.create_uri(type, params)
        service = PleromaService.new
        params[:id] ||= params[:status_id]
        case type.to_sym
        in :public
          return service.create_uri("/notice/#{params[:id]}")
        in :webui
          return service.create_uri("/mulukhiya/app/status/#{params[:id]}")
        end
      end

      def attachments
        return data[:media_attachments] || []
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

      def self.[](id)
        return new(id)
      end

      # 投稿が消されたと分かる上流の応答（5.47.0 のリリース前レビュー）。→ `Account#status_entry`
      DELETED_SOURCE_STATUSES = [404, 410].freeze

      # 読み込みの失敗が「消された投稿」によるものか。それ以外（停止・失効・タイムアウト）は false。
      def self.deleted_error?(error)
        return false unless error.is_a?(Ginseng::GatewayError)
        return DELETED_SOURCE_STATUSES.member?(error.source_status)
      end
    end
  end
end
