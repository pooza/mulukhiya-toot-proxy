module Mulukhiya
  class PackageTest < TestCase
    def setup
      @package = YAML.load_file(File.join(Environment.dir, 'config/application.yaml'))['package']
    end

    def test_name
      assert_equal(Package.name, 'mulukhiya')
    end

    def test_version
      assert_equal(Package.version, @package['version'])
    end

    def test_full_name
      assert_equal(Package.full_name, "mulukhiya #{@package['version']}")
    end

    def test_user_agent
      assert_equal(Package.user_agent, "mulukhiya/#{@package['version']} (#{@package['url']})")
    end
  end
end
