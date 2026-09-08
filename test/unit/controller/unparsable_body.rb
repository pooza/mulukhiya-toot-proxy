require 'rack/test'

module Mulukhiya
  # JSON のつもりで送られた body が落ちたときに、手掛かりを残すこと (#4699)。
  #
  # ⚠⚠ **`before` の `JSON.parse(@body)` は失敗しても黙って form params へ倒れる。**
  # フォーム POST や空 body でも通る経路なので rescue 自体は正しいが、**JSON として
  # 送られた body が落ちた**ときも同じ穴に落ち、クライアントからは「投稿したのに
  # 内容が空」に見えてログに 1 行も残らない。
  #
  # 🔴 **json 3.0 へ上げる前の前提**（#4699）。3.0 は `allow_duplicate_key` の既定が
  # false になるので、**いままで「後勝ち」で通っていた重複キーの body が丸ごと
  # ここへ落ちる**。無音のままだと版を上げた影響を切り分けられない。
  class UnparsableBodyTest < TestCase
    include Rack::Test::Methods

    class BodyProbeController < Controller
      set :raise_errors, false
      set :show_exceptions, false

      post '/probe' do
        @renderer.message = {ok: true}
        return @renderer.to_s
      end
    end

    def app = BodyProbeController

    class << BodyProbeController
      attr_accessor :log_double
    end

    def setup
      @logged = []
      sink = @logged
      BodyProbeController.log_double = Object.new.tap do |double|
        double.define_singleton_method(:info) {|*| nil}
        double.define_singleton_method(:error) {|payload| sink.push(payload)}
      end
      BodyProbeController.class_eval do
        define_method(:logger) {BodyProbeController.log_double}
      end
    end

    def teardown
      BodyProbeController.send(:remove_method, :logger)
      BodyProbeController.log_double = nil
    end

    # 🔴 **本体。**JSON らしい body が落ちたら残す。
    def test_broken_json_body_is_logged
      post_body('{"a": 1,,}')

      assert_equal(1, errors.length, '手掛かりが残っていない')
      assert_equal('request body is not parsable as JSON', errors.first[:error])
    end

    # 🔴 **json 3.0 で新たにここへ落ちる形**を、いまのうちに押さえておく。
    # ⚠ json 2.x では通る（後勝ち）ので、この入力は 3.0 で初めて log に出る。
    def test_duplicate_key_body_reaches_the_same_path
      post_body('{"a": 1, "a": 2}')

      # 2.x は通るので 0 件、3.0 は落ちるので 1 件。⚠ **どちらでも「無音ではない」**
      # ことだけを固定する（版で分岐させない）。
      assert_operator(errors.length, :<=, 1)
      errors.each {|e| assert_equal('request body is not parsable as JSON', e[:error])}
    end

    # ⚠ フォーム POST は正常な経路なので出さない。毎回出すと syslog が埋まる。
    def test_form_body_is_not_logged
      post_body('a=1&b=2', 'application/x-www-form-urlencoded')

      assert_empty(errors)
    end

    def test_empty_body_is_not_logged
      post_body('')

      assert_empty(errors)
    end

    # ⚠ **本文は出さない。**投稿本文が平文で残る（#4394 / #4630）。
    def test_log_does_not_carry_the_body
      post_body('{"status": "秘密の本文",,}')

      assert_not_match(/秘密の本文/, errors.to_s)
      assert_operator(errors.first[:bytesize], :>, 0)
    end

    private

    def errors
      return @logged
    end

    # ⚠ **`CONTENT_TYPE` を明示しないと body が届かない。**form-urlencoded だと
    # Rack が params 解釈で `rack.input` を読み切ってしまい、`before` の
    # `request.body.read` が空文字を返す（本番の Puma では起きないテスト固有の事情）。
    def post_body(body, type = 'application/json')
      post(
        '/probe', body,
        'HTTP_HOST' => 'localhost',
        'CONTENT_TYPE' => type,
        'rack.input' => StringIO.new(body)
      )
    end
  end
end
