module Mulukhiya
  module Pleroma
    class Application < Sequel::Model(:apps)
      alias name client_name
    end
  end
end
