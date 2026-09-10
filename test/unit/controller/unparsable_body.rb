require 'rack/test'

module Mulukhiya
  # JSON のつもりで送られた body が落ちたときに、手掛かりを残すこと (#4699)。
  #
  # ⚠⚠ **`before` の `JSON.parse(@body)` は失敗しても黙って form params へ倒れる。**
  # フォーム POST や空 body でも通る経路なので rescue 自体は正しいが、**JSON として
  # 送られた body が落ちた**ときも同じ穴に落ち、クライアントからは「投稿したのに
  # 内容が空」に見えてログに 1 行も残らない。
  #
  # ⚠ **ここの `JSON.parse` は json gem ではなく Yajl**（ginseng-core が引く
  # `yajl/json_gem` が差し替えている・#4699）。json の版を上げても、この経路の
  # 解釈は変わらない。
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

    # ⚠ **重複キーの body は Yajl では後勝ちで通る**ので、ここへは落ちない。
    # ⚠⚠ **パーサが json gem（3.0 以降）に戻ると落ちるようになる**＝このテストが
    # 赤くなったら、`JSON.parse` の差し替えが外れたということ（#4699 の前提が変わる）。
    def test_duplicate_key_body_is_parsed_by_yajl
      post_body('{"a": 1, "a": 2}')

      assert_empty(errors, '重複キーの body が解釈できていない（パーサが変わった？）')
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

    # 🔴 **本文は出さない**（#4394 / #4630・PR #4708 の Codex P1）。
    #
    # ⚠⚠ **パーサのメッセージは壊れた入力をそのまま反響しうる。**json gem 素の
    # `JSON.parse` は実測でこう出る:
    #
    #   unexpected character: '秘密の本文}' at line 1 column 12
    #   expected ',' or '}' after object value, got: '秘密のトークンabc123}'
    #
    # ⚠⚠ **アプリ内の Yajl も反響する**（メッセージの 2 行目に入力がそのまま入る）。
    # ⚠⚠ しかも **ASCII-8BIT** なので、`errors.to_s` では日本語が `\xE7\xA7...` に
    # エスケープされ、**日本語の正規表現では漏れていても一致しない**（旧版のこのテストは
    # それで false negative だった）。**ASCII 部分で見るのと、UTF-8 に戻して見るのを両方やる。**
    #
    # ⚠ `,,` のような入力だと反響部分が記号だけになるので、実際に本文が
    # 反響しうる入力で見ること。
    def test_log_does_not_carry_the_body
      ['{"status": 秘密の本文}', '{"a": "x" 秘密のトークンabc123}'].each do |body|
        @logged.clear
        post_body(body)
        values = errors.flat_map {|e| e.values.map {|v| v.to_s.dup.force_encoding(Encoding::UTF_8)}}

        assert_equal(1, errors.length)
        assert_not_match(/abc123/, errors.to_s, '本文（ASCII 部分）が反響している')
        assert(values.none? {|v| v.scrub.match?(/秘密の(本文|トークン)/)}, '本文が反響している')
        assert_operator(errors.first[:bytesize], :>, 0)
      end
    end

    # ⚠ 例外メッセージそのものを載せない（長さの上限が無く、巨大な 1 行にもなる）。
    def test_log_carries_no_exception_message
      post_body('{"a": 1,,}')

      refute(errors.first.key?(:message), 'message を載せている')
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
