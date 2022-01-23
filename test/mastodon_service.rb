require 'securerandom'

module Mulukhiya
  class MastodonServiceTest < TestCase
    def setup
      @service = MastodonService.new
      @key = SecureRandom.hex(16).adler32
    end

    def test_filters

      ic @SNSServiceMethods

    end
  end
end
