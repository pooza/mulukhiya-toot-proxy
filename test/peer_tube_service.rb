module Mulukhiya
  class PeerTubeServiceTest < TestCase
    def setup
      @service = PeerTubeService.new(config['/peer_tube/hosts'].first)
    end

    def test_lookup
      assert_raises(Ginseng::GatewayError) do
        @service.lookup('iKu2ASqiBm796yuzqdx9Z')
      end

      assert_kind_of(Hash, @service.lookup('taaJ1Sh8b5JvHUZeFD1Jzk'))
    end
  end
end
