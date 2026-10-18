module Mulukhiya
  # Pleroma 系の ID の表記 (#4566)。組は dev29 の Akkoma 3.20.1 の実物。
  class FlakeIdTest < TestCase
    PAIRS = {
      '000001a1-41a5-f9ae-ebad-ac9c5de10000' => 'BBRwXUDu0uwfOACCsy',
    }.freeze

    def test_encode
      PAIRS.each {|uuid, id| assert_equal(id, FlakeId.encode(uuid))}
    end

    def test_decode
      PAIRS.each {|uuid, id| assert_equal(uuid, FlakeId.decode(id))}
    end

    def test_round_trip
      uuid = SecureRandom.uuid

      assert_equal(uuid, FlakeId.decode(FlakeId.encode(uuid)))
    end

    def test_invalid
      assert_raise(ArgumentError) {FlakeId.decode('not-a-flake!')}
    end
  end
end
