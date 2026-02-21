module Mulukhiya
  class PreTootPipelineTest < TestCase
    def setup
      WebMock.disable_net_connect!(allow_localhost: true)
      @sns = sns_class.new('https://sns.test', 'test_token')
      def @sns.account = nil
      config['/agent/accts'] = ['@relayctl@hashtag-relay.dtp-mstdn.jp']
    end

    def test_plain_text
      payload = {
        status_field => '普通の投稿テキストです。',
        visibility_field => '',
      }
      reporter = create_event.dispatch(payload)

      assert_kind_of(Reporter, reporter)
      assert_equal('普通の投稿テキストです。', payload[status_field].strip)
    end

    def test_agent_mention_visibility
      payload = {
        status_field => '@relayctl@hashtag-relay.dtp-mstdn.jp subscribe #mulukhiya',
        visibility_field => '',
      }
      create_event.dispatch(payload)

      assert_equal(controller_class.visibility_name(:direct), payload[visibility_field])
    end

    def test_tagging
      payload = {
        status_field => "本文テキスト\n#タグ1\n#タグ2",
        visibility_field => '',
      }
      create_event.dispatch(payload)
      text = payload[status_field]

      assert_includes(text, '本文テキスト', 'body text should be preserved')
      assert_includes(text, '#タグ1', 'tag1 should be present')
      assert_includes(text, '#タグ2', 'tag2 should be present')
      assert_operator(text.index('本文テキスト'), :<, text.index('#タグ'), 'tags should follow body text')
    end

    def test_command_break
      payload = {
        status_field => 'command: user_config',
        visibility_field => '',
      }
      reporter = create_event.dispatch(payload)

      assert_equal(controller_class.visibility_name(:direct), payload[visibility_field])

      tagging_executed = reporter.any? {|entry| entry[:handler] == 'tagging'}

      assert_false(tagging_executed, 'tagging handler should not run after command break')
    end

    def test_spoiler_with_tags
      payload = {
        spoiler_field => 'ネタバレ注意',
        status_field => "本文\n#タグ",
        visibility_field => '',
      }
      create_event.dispatch(payload)

      # SpoilerHandler depends on status_class (Sequel model).
      # In CI without DB, the handler errors gracefully; verify pipeline resilience.
      assert_includes(payload[spoiler_field], 'ネタバレ', 'CW text should survive pipeline')
      assert_includes(payload[status_field], '#タグ', 'tag should be preserved')
    end

    def test_pipeline_handler_count
      event = Event.new(:pre_toot)
      count = event.all_handler_names.count

      assert_operator(count, :>=, 10, 'pipeline should have at least 10 handlers')
    end

    def test_pipeline_order
      names = Event.new(:pre_toot).all_handler_names.to_a
      mention_idx = names.index('mention_visibility')
      tagging_idx = names.index('tagging')
      spoiler_idx = names.index('spoiler')

      assert_not_nil(mention_idx)
      assert_not_nil(tagging_idx)
      assert_not_nil(spoiler_idx)
      assert_operator(mention_idx, :<, tagging_idx, 'mention_visibility should run before tagging')
      assert_operator(spoiler_idx, :<, tagging_idx, 'spoiler should run before tagging')
    end

    def test_disabled_handlers_skipped
      payload = {
        status_field => '普通の投稿テキストです。',
        visibility_field => '',
      }
      reporter = create_event.dispatch(payload)
      executed_handlers = reporter.filter_map {|entry| entry[:handler]}

      assert_false(executed_handlers.include?('spotify_nowplaying'), 'spotify should be disabled in CI')
      assert_false(executed_handlers.include?('you_tube_image'), 'youtube should be disabled in CI')
    end

    private

    def create_event
      Event.new(:pre_toot, sns: @sns)
    end
  end
end
