require 'webmock/test_unit'

module Mulukhiya
  class GroupTagHandlerTest < TestCase
    def setup
      return if disable?
      WebMock.disable_net_connect!
      @handler = Handler.create(:group_tag)
      stub_community_map
    end

    def teardown
      WebMock.allow_net_connect!
      redis.del(GroupTagHandler::CACHE_KEY)
    end

    def test_handle_pre_toot_with_matching_acct
      @handler.handle_pre_toot(status_field => '@precure_fun@pf.korako.me こんにちは')

      assert_includes(@handler.addition_tags, 'precure_fun')
    end

    def test_handle_pre_toot_with_multiple_hashtags
      @handler.handle_pre_toot(status_field => '@dqx_online@pf.korako.me ドラクエ楽しい')

      assert_includes(@handler.addition_tags, 'DQ10')
      assert_includes(@handler.addition_tags, 'DQX')
    end

    def test_handle_pre_toot_without_matching_acct
      @handler.handle_pre_toot(status_field => '@nobody@example.com こんにちは')

      assert_predicate(@handler.addition_tags.count, :zero?)
    end

    def test_handle_pre_toot_without_mention
      @handler.handle_pre_toot(status_field => 'メンションなしの投稿')

      assert_predicate(@handler.addition_tags.count, :zero?)
    end

    private

    def stub_community_map
      body = {
        communities: [
          {acct: 'precure_fun@pf.korako.me', hashtags: ['precure_fun'], id: 17, title: 'プリキュア'},
          {acct: 'dqx_online@pf.korako.me', hashtags: ['DQ10', 'DQX'], id: 38, title: 'ドラゴンクエスト10'},
        ],
      }.to_json
      stub_request(:get, 'https://pf.korako.me/plugins/community-hashtag-map.json')
        .to_return(status: 200, body:, headers: {'Content-Type' => 'application/json'})
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
