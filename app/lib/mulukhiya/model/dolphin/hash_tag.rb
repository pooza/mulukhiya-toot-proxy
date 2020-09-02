module Mulukhiya
  module Dolphin
    class HashTag < Sequel::Model(:hashtag)
      def uri
        @uri ||= Environment.sns_class.new.create_uri("/tags/#{name}")
        return @uri
      end

      alias to_h values

      def self.get(key)
        return HashTag.first(name: key[:tag]) if key.key?(:tag)
        return HashTag.first(key)
      end
    end
  end
end
