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

    def test_count
      assert_kind_of(Integer, CustomFeed.count)
    end

    def test_create
      CustomFeed.entries.each do |entry|
        feed = @feeds.create(entry)
        assert_kind_of(RSS20FeedRenderer, feed)
        assert(feed.to_s.present?)
        assert_kind_of(CommandLine, feed.command)
        feed.command.exec
        entries = JSON.parse(feed.command.stdout)
        assert_kind_of(Array, entries)
        assert(entries.present?)
      end
    end
  end
end
