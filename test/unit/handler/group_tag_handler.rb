require 'webmock/test_unit'

module Mulukhiya
  class GroupTagHandlerTest < TestCase
    def setup
      return if disable?
      # community-map は下でスタブする一方、GroupTagHandler は local instance 解決で
      # harness の SNS（localhost）へ実アクセスする。allow_localhost で harness を通し、
      # 外部（pf.korako.me）はスタブに閉じる。
      WebMock.disable_net_connect!(allow_localhost: true)
      # community_map は redis(CACHE_KEY)にキャッシュされ他テストと共有される。前段のテスト
      # （例 PreTootPipelineTest）が空マップを残していると cache_valid? が true になり本テストの
      # スタブが fetch されない。setup で必ず消して毎回スタブから引き直す（順序非依存化）。
      redis.del(GroupTagHandler::CACHE_KEY)
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
