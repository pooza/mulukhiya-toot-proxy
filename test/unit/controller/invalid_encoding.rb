require 'rack/test'

module Mulukhiya
  # 不正な UTF-8 バイト列を含むリクエストを、入口で 400 に落とす (#4600)。
  #
  # 🔴 `JSON.parse` も Rack のフォームのパースも壊れたバイト列を弾かないので、奥の
  # `TootParser#tags` などで `ArgumentError` になり、クライアントのバグが 500 ＋ Sentry に
  # 化けていた。ログで伏せないキーに来ると、リクエストログが先に落ちて 401 に化ける。
  class InvalidEncodingTest < TestCase
    include Rack::Test::Methods

    BROKEN = "\xE3\x81ほげ".freeze

    class EncodingProbeController < Controller
      set :raise_errors, false
      set :show_exceptions, false

      post '/probe' do
        @renderer.message = {ok: true, status: params[:status]}
        return @renderer.to_s
      end
    end

    def app = EncodingProbeController

    class << EncodingProbeController
      attr_accessor :log_double, :reported
    end

    def setup
      @logged = []
      sink = @logged
      EncodingProbeController.reported = []
      EncodingProbeController.log_double = Object.new.tap do |double|
        double.define_singleton_method(:info) {|*| nil}
        double.define_singleton_method(:error) {|payload| sink.push(payload)}
      end
      EncodingProbeController.class_eval do
        define_method(:logger) {EncodingProbeController.log_double}
        define_method(:report_error) {|e, *| EncodingProbeController.reported.push(e)}
      end
    end

    def teardown
      EncodingProbeController.send(:remove_method, :logger)
      EncodingProbeController.send(:remove_method, :report_error)
      EncodingProbeController.log_double = nil
    end

    # 🔴 JSON の本文はパーサ（Yajl）が弾くので、従来は本文ごと捨てられて「内容が空」の
    # 要求として奥へ進んでいた。どのキーかは分からないので `body` と残す。
    def test_broken_json_body_is_rejected_as_bad_request
      post_json(%({"status": "#{BROKEN}"}))

      assert_rejected('body')
    end

    def test_broken_nested_json_body_is_rejected_as_bad_request
      post_json(%({"poll": {"options": ["ok", "#{BROKEN}"]}}))

      assert_rejected('body')
    end

    # ⚠ ログで伏せないキー（ALT など）。リクエストログの `to_json` が先に落ちると、
    # `before` の rescue がトークンを外して 401 に化ける。ログより前に落とすこと。
    def test_broken_form_value_in_unscrubbed_key_is_rejected_as_bad_request
      post('/probe', "description=#{BROKEN}".b, {
        'HTTP_HOST' => 'localhost',
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      })

      assert_rejected('description')
    end

    def test_broken_nested_form_value_is_rejected_as_bad_request
      post('/probe', "poll[options][]=ok&poll[options][]=#{BROKEN}".b, {
        'HTTP_HOST' => 'localhost',
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      })

      assert_rejected('options')
    end

    def test_broken_form_value_is_rejected_as_bad_request
      post('/probe', "status=#{BROKEN}".b, {
        'HTTP_HOST' => 'localhost',
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      })

      assert_rejected('status')
    end

    # ⚠ 正常な UTF-8 を誤検知しないこと（絵文字・結合文字・サロゲート相当の 4 バイト）。
    def test_valid_utf8_passes
      text = "プリキュア🌈 か\u3099 👨‍👩‍👧 𠮷野家"
      post_json({status: text}.to_json)

      assert_equal(200, last_response.status)
      assert_equal(text, JSON.parse(last_response.body)['status'])
      assert_empty(@logged)
    end

    def test_empty_body_passes
      post('/probe', '', {'HTTP_HOST' => 'localhost'})

      assert_equal(200, last_response.status)
    end

    private

    def post_json(body)
      post('/probe', body.b, {'HTTP_HOST' => 'localhost', 'CONTENT_TYPE' => 'application/json'})
    end

    def assert_rejected(key)
      assert_equal(400, last_response.status)
      assert_match(/UTF-8/, JSON.parse(last_response.body)['error'])
      # ⚠ JSON の本文では「パースできない」の行（#4699）も 1 本出るので、自分の行だけ数える。
      rejected = @logged.select {|v| v[:error] == 'request contains invalid byte sequence'}

      assert_equal(1, rejected.length)
      assert_equal(key, rejected.first[:key])
      assert_empty(EncodingProbeController.reported, 'Sentry・通知へ出している')
    end
  end
end
