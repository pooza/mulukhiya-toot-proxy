module Mulukhiya
  module Misskey
    class Attachment < Sequel::Model(:drive_file)
      def to_h
        @hash ||= values.clone.compact
        return @hash
      end

      def uri
        @uri ||= Ginseng::URI.parse(url)
        return @uri
      end
    end
  end
end
