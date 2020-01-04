module MulukhiyaTootProxy
  module Dolphin
    class Attachment < Sequel::Model(:drive_file)
      alias to_h values
    end
  end
end
