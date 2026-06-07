module Mulukhiya
  class ScheduledStatusTagUpdaterTest < TestCase
    class FakeResponse
      attr_reader :code

      def initialize(code, parsed = {})
        @code = code
        @parsed = parsed
      end

      def parsed_response
        return @parsed
      end
    end

    class FakeParser
      def initialize(body)
        @body = body
      end

      def body
        return @body.to_s.split("\n\n").first.to_s
      end
    end

    class FakeAccount
      attr_reader :id

      def initialize(id)
        @id = id
      end
    end

    class FakeSns
      attr_reader :deleted_id, :toots, :account

      def initialize(toot_responses)
        @toot_responses = Array(toot_responses)
        @toots = []
        @account = FakeAccount.new(99)
      end

      def status_field
        return 'status'
      end

      def parser_class
        return FakeParser
      end

      def delete_scheduled_status(id)
        @deleted_id = id
        return FakeResponse.new(200)
      end

      def toot(params)
        @toots.push(params)
        return @toot_responses.shift
      end
    end

    class FakeFailingDeleteSns < FakeSns
      def delete_scheduled_status(id)
        @deleted_id = id
        return FakeResponse.new(404, {'error' => 'gone'})
      end
    end

    class FakeStorage
      attr_reader :unlinked, :stored

      def initialize
        @stored = {}
      end

      def unlink(id)
        @unlinked = id
      end

      def set(id, values, ttl: nil)
        @stored[id] = {values:, ttl:}
      end
    end

    def setup
      @entry = {
        params: {status: "本文\n\n#旧タグ", visibility: 'public'},
        scheduled_at: (Time.now + 7200).iso8601,
        account_id: 99,
      }
      @storage = FakeStorage.new
    end

    def test_rewrites_body_with_given_tags_and_recreates
      created_at = (Time.now + 7200).iso8601
      sns = FakeSns.new(FakeResponse.new(200, {'id' => '200', 'scheduled_at' => created_at}))
      result = ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo', 'bar'])

      assert_equal("本文\n\n#foo #bar", sns.toots.first['status'])
      assert_equal({id: '200', scheduled_at: created_at, tags: ['foo', 'bar']}, result)
    end

    def test_preserves_other_params_on_recreate
      sns = FakeSns.new(FakeResponse.new(200, {'id' => '200', 'scheduled_at' => @entry[:scheduled_at]}))
      ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo'])

      assert_equal('public', sns.toots.first['visibility'])
      assert_equal(@entry[:scheduled_at], sns.toots.first['scheduled_at'])
    end

    def test_deletes_original_before_recreating
      sns = FakeSns.new(FakeResponse.new(200, {'id' => '200', 'scheduled_at' => @entry[:scheduled_at]}))
      ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo'])

      assert_equal('100', sns.deleted_id)
    end

    def test_unlinks_old_and_stores_new_entry_on_success
      created_at = (Time.now + 7200).iso8601
      sns = FakeSns.new(FakeResponse.new(200, {'id' => '200', 'scheduled_at' => created_at}))
      ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo'])

      assert_equal('100', @storage.unlinked)
      assert(@storage.stored.key?('200'))
      assert_equal(99, @storage.stored['200'][:values][:account_id])
      assert_operator(@storage.stored['200'][:ttl], :>=, ScheduledStatusSaveHandler::MARGIN)
    end

    def test_raises_gateway_error_when_delete_fails
      sns = FakeFailingDeleteSns.new([])
      assert_raises(Ginseng::GatewayError) do
        ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo'])
      end
      assert_empty(sns.toots)
    end

    def test_rolls_back_to_original_body_when_recreate_fails
      sns = FakeSns.new([
        FakeResponse.new(422, {'error' => 'rejected'}),
        FakeResponse.new(200, {'id' => '300'}),
      ])
      assert_raises(Ginseng::GatewayError) do
        ScheduledStatusTagUpdater.new(sns, @storage).call('100', @entry, ['foo'])
      end

      assert_equal(2, sns.toots.size)
      assert_equal("本文\n\n#foo", sns.toots.first['status'])
      assert_equal("本文\n\n#旧タグ", sns.toots.last['status'])
      assert_nil(@storage.unlinked)
      assert_empty(@storage.stored)
    end
  end
end
