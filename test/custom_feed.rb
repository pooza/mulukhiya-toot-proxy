module Mulukhiya
  class CustomFeedTest < TestCase
    def test_all
      CustomFeed.all do |feed|
        assert_kind_of(CustomFeed, feed)
      end
    end

    def test_count
      assert_kind_of(Integer, CustomFeed.count)
    end

    def test_path
      CustomFeed.all do |feed|
        assert_kind_of(String, feed.path)
      end
    end

    def test_fullpath
      CustomFeed.all do |feed|
        assert_kind_of(String, feed.fullpath)
      end
    end

    def test_title
      CustomFeed.all do |feed|
        assert_kind_of(String, feed.title)
      end
    end

    def test_command
      CustomFeed.all do |feed|
        assert_kind_of(CommandLine, feed.command)
      end
    end

    def test_renderer
      CustomFeed.all do |feed|
        assert_kind_of(RSS20FeedRenderer, feed.renderer)
      end
    end
  end
end
