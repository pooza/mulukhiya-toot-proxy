module Mulukhiya
  class StatusTagAddServiceTest < TestCase
    class FakeTag
      def initialize(name)
        @name = name
      end

      def to_hashtag
        return "##{@name}"
      end
    end

    class FakeParser
      attr_reader :body, :footer_tags

      def initialize(body, initial_tags = [])
        @body = body
        @footer_tags = initial_tags.dup
      end
    end

    class FakeStatus
      attr_reader :parser

      def initialize(body, initial_tags = [])
        @parser = FakeParser.new(body, initial_tags)
      end
    end

    class FakeSns
      attr_reader :received_status, :received_body

      def initialize(result = {ok: true})
        @result = result
      end

      def repost(status, body)
        @received_status = status
        @received_body = body
        return @result
      end
    end

    def setup
      @sns = FakeSns.new
      @service = StatusTagAddService.new(@sns)
    end

    def test_replaces_footer_tags_with_given_tags
      status = FakeStatus.new('本文', [FakeTag.new('旧タグ')])
      tags = [FakeTag.new('新タグ1'), FakeTag.new('新タグ2')]

      @service.call(status, tags)

      assert_equal(tags, status.parser.footer_tags)
    end

    def test_appends_hashtags_after_blank_line_to_body
      status = FakeStatus.new('本文')
      tags = [FakeTag.new('foo'), FakeTag.new('bar')]

      @service.call(status, tags)

      assert_equal("本文\n\n#foo #bar", @sns.received_body)
    end

    def test_returns_sns_repost_result
      status = FakeStatus.new('本文')
      sns = FakeSns.new({id: 42, content: '本文'})
      service = StatusTagAddService.new(sns)

      result = service.call(status, [FakeTag.new('tag')])

      assert_equal({id: 42, content: '本文'}, result)
    end

    def test_passes_status_through_to_sns
      status = FakeStatus.new('本文')

      @service.call(status, [FakeTag.new('tag')])

      assert_same(status, @sns.received_status)
    end

    def test_empty_tags_produces_trailing_blank_line
      status = FakeStatus.new('本文', [FakeTag.new('旧')])

      @service.call(status, [])

      assert_equal("本文\n\n", @sns.received_body)
      assert_empty(status.parser.footer_tags)
    end
  end
end
