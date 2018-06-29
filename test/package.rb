require 'mulukhiya/package'

module MulukhiyaTootProxy
  class PackageTest < Test::Unit::TestCase
    def test_name
      assert_equal(Package.name, 'mulukhiya-toot-proxy')
    end
  end
end
