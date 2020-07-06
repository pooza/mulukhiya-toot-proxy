module Mulukhiya
  module Dolphin
    class Status < Mulukhiya::Misskey::Status
      def account
        @account ||= Account[userId]
        return @account
      end

      def to_h
        unless @hash
          @hash = values.clone
          @hash[:uri] ||= uri.to_s
          @hash[:attachments] = attachments.map(&:to_h)
        end
        return @hash
      end

      def uri
        unless @uri
          if self[:uri].present?
            @uri = TootURI.parse(self[:uri])
            @uri = NoteURI.parse(self[:uri]) unless @uri&.valid?
            @uri = nil unless @uri&.valid?
          else
            @uri = NoteURI.parse(Config.instance['/dolphin/url'])
            @uri.path = "/notes/#{id}"
          end
        end
        return @uri
      end
    end
  end
end
