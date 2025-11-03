module Mulukhiya
  module Misskey
    class Decoration < Sequel::Model(:avatar_decoration)
      include Package
      include SNSMethods

      def to_h
        return values.deep_symbolize_keys
      end

      def livecure?
        return name.include('実況')
      end

      def uri
        @uri ||= Ginseng::URI.parse(url)
        return @uri
      end
    end
  end
end
