module Mulukhiya
  module Meisskey
    class Account
      def initialize(id)
      end

      def self.[](id)
        return Account.new(id)
      end

      def notify_verbose?
        return false
      end

      def tags
        return []
      end

      def disable?(handler_name)
        return false
      end

      def twitter
        return nil
      end

      def self.get(key)
        return Account[1]
      end
    end
  end
end
