module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status

      def to_h
        @hash ||= values.clone.compact
        return @hash
      end

      alias type file_content_type
    end
  end
end
