module Mulukhiya
  module Refines
    class ::String
      def encrypt
        return Crypt.new.encrypt(self)
      end

      def decrypt
        return Crypt.new.decrypt(self)
      end

      def nokogiri
        require 'nokogiri'
        return Nokogiri::HTML.parse(force_encoding('utf-8'), nil, 'utf-8')
      end
    end
  end
end
