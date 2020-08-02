module Mulukhiya
  module Dolphin
    class Status < Mulukhiya::Misskey::Status
      include StatusMethods

      many_to_one :account, key: :userId
    end
  end
end
