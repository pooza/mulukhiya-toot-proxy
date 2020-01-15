module Mulukhiya
  class PackageTest < TestCase
    def setup
      @package = YAML.load_file(File.join(Environment.dir, 'config/application.yaml'))['package']
    end

    def test_name
      assert_equal(Package.name, 'mulukhiya-toot-proxy')
    end

    def test_version
      assert_equal(Package.version, @package['version'])
    end

    def test_full_name
      assert_equal(Package.full_name, "mulukhiya-toot-proxy #{@package['version']}")
    end

    def test_user_agent
      assert_equal(Package.user_agent, "mulukhiya-toot-proxy/#{@package['version']} (#{@package['url']})")
    end
  end
end
