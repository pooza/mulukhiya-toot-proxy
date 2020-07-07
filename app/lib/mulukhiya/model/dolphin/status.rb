module Mulukhiya
  module Dolphin
    class Status < Mulukhiya::Misskey::Status
      def account
        @account ||= Account[userId]
        return @account
      end
    end
  end
end
