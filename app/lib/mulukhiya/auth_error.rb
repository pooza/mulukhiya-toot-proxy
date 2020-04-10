module Mulukhiya
  class AuthError < Ginseng::Error
    def status
      return 403
    end
  end
end
