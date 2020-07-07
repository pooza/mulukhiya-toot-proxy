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
    end
  end
end
