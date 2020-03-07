module Mulukhiya
  module Dolphin
    class Status < Mulukhiya::Misskey::Status
      def account
        @account ||= Account[userId]
        return @account
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
