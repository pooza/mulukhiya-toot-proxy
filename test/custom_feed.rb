module Mulukhiya
  class CustomFeedTest < TestCase
    def setup
      @feeds = CustomFeed.instance
    end

    def test_entries
      CustomFeed.entries.each do |entry|
        assert_kind_of(String, entry['path'])
        assert_kind_of([Array, String], entry['command'])
        assert_kind_of(String, entry['title'])
        assert_kind_of(String, entry['description'])
        assert(URI.parse(entry['link']).absolute?)
      end
    end
  end
end
