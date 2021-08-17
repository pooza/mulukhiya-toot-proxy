module Mulukhiya
  class CustomAPITest < TestCase
    def setup
      @apis = CustomAPI.instance
    end

    def test_entries
      CustomAPI.entries.each do |entry|
        assert_kind_of(String, entry['path'])
        assert_kind_of([Array, String], entry['command'])
        assert_kind_of(String, entry['title'])
        assert(Dir.exist?(entry['dir']))
      end
    end

    def test_count
      assert_kind_of(Integer, CustomAPI.count)
    end
  end
end
