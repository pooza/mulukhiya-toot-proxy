module MulukhiyaTootProxy
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status

      alias to_h values
    end
  end
end
