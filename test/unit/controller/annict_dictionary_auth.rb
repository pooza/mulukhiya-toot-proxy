require 'rack/test'

module Mulukhiya
  # エピソード辞書の口は、鍵が無ければ Annict を引かずに断る (#4865)。
  #
  # ⚠ 辞書を丸ごと誰でも取れる URL に置くのは、Annict の API 利用規約 第 6 条にあたる。
  # ⚠ DB にも Annict にも繋がない。鍵が合わないときだけを見る。
  class AnnictDictionaryAuthTest < TestCase
    include Rack::Test::Methods

    class FakeControllerClass
      def self.annict?
        return true
      end
    end

    class AnnictDictionaryProbeController < APIController
      set :raise_errors, false
      set :show_exceptions, false

      def controller_class
        return FakeControllerClass
      end
    end

    ENV_LOCALHOST = {'HTTP_HOST' => 'localhost', input: ''}.freeze

    def setup
      @keys = config['/service/annict/dictionary/keys']
      config['/service/annict/dictionary/keys'] = ['0123456789abcdef']
    end

    def teardown
      config['/service/annict/dictionary/keys'] = @keys
    end

    def app
      return AnnictDictionaryProbeController
    end

    def test_requires_key
      get('/tagging/dic/annict/episodes', {}, ENV_LOCALHOST)

      assert_equal(403, last_response.status)
    end

    def test_rejects_wrong_key
      get('/tagging/dic/annict/episodes', {key: '0123456789abcdeX'}, ENV_LOCALHOST)

      assert_equal(403, last_response.status)
    end
  end
end
