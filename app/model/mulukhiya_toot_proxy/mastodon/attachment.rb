module MulukhiyaTootProxy
  module Mastodon
    class Attachment < Sequel::Model(:media_attachments)
      many_to_one :status
    end
  end
end
