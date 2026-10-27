require 'rack/test'

module Mulukhiya
  # エピソードブラウザの口は、SNS のトークンが無ければ Annict を引かずに断る (#4865)。
  #
  # ⚠ お知らせボットの Annict トークンで引いた作品・各話を返すので、認証なしだと第三者が
  # 取り出せる（Annict の API 利用規約 第 6 条）。
  # ⚠ DB にも Annict にも繋がない。トークンが無いときだけを見る。
  class ProgramWorksAuthTest < TestCase
    include Rack::Test::Methods

    class FakeService
      attr_accessor :token

      def account
        return nil
      end
    end

    class ProgramWorksProbeController < APIController
      set :raise_errors, false
      set :show_exceptions, false

      def sns_class
        return FakeService
      end
    end

    ENV_LOCALHOST = {'HTTP_HOST' => 'localhost', input: ''}.freeze

    def app
      return ProgramWorksProbeController
    end

    def test_works_requires_account
      get('/program/works', {}, ENV_LOCALHOST)

      assert_equal(403, last_response.status)
    end

    def test_episodes_requires_account
      get('/program/works/1/episodes', {}, ENV_LOCALHOST)

      assert_equal(403, last_response.status)
    end
  end
end
