module Mulukhiya
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status

      alias to_h values

      alias type file_content_type
    end
  end
end
