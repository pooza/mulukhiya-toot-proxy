module Mulukhiya
  class HTTP < Ginseng::HTTP
    include Package
    attr_accessor :retry

    def retry_limit
      return @retry || config['/http/retry/limit']
    end
  end
end
