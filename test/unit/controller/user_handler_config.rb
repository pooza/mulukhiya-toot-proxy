require 'rack/test'

module Mulukhiya
  # 利用者がハンドラを切り替える `POST /handler/config` (#4196)。
  #
  # ⚠ DB と Redis に繋がない。トークンの持ち主と利用者の設定は偽物で決める。
  class UserHandlerConfigTest < TestCase
    include Rack::Test::Methods

    class FakeUserConfig
      attr_reader :values

      def initialize
        @values = {}
      end

      def update!(values)
        values.deep_stringify_keys.key_flatten.each {|k, v| @values[k] = v}
      end

      def [](key)
        return @values[key]
      end
    end

    class FakeAccount
      def user_config
        return @user_config ||= FakeUserConfig.new
      end
    end

    class FakeService
      attr_accessor :token

      def account
        return nil unless token
        return @account ||= FakeAccount.new
      end

      def writable_token?
        return true
      end
    end

    class ProbeController < APIController
      set :raise_errors, false
      set :show_exceptions, false

      def sns
        return @sns ||= FakeService.new.tap {|s| s.token = token}
      end
    end

    ENV_LOCALHOST = {'HTTP_HOST' => 'localhost', 'CONTENT_TYPE' => 'application/json'}.freeze
    NAMES = ['default_tag', 'invalid_command'].freeze

    def setup
      # ⚠ 設定に無いキーは `ConfigError` になる。無かったものは false で戻す。
      @originals = NAMES.to_h {|name| [name, (config["/handler/#{name}/disable"] rescue false)]}
      NAMES.each {|name| config["/handler/#{name}/disable"] = false}
    end

    def teardown
      @originals&.each {|name, value| config["/handler/#{name}/disable"] = value}
    end

    def app
      return ProbeController
    end

    def test_user_toggleable
      assert_equal('default_tag', Handler.user_toggleable('default_tag', NAMES))
    end

    def test_user_toggleable_requires_name
      assert_raise(Ginseng::RequestError) {Handler.user_toggleable(nil, NAMES)}
      assert_raise(Ginseng::RequestError) {Handler.user_toggleable('', NAMES)}
    end

    # 一覧に無い名前は constantize に渡さない。
    def test_user_toggleable_rejects_unknown
      assert_raise(Ginseng::NotFoundError) {Handler.user_toggleable('kernel', NAMES)}
      assert_raise(Ginseng::NotFoundError) {Handler.user_toggleable('image_resize', NAMES)}
    end

    def test_user_toggleable_rejects_globally_disabled
      config['/handler/default_tag/disable'] = true

      assert_raise(Ginseng::NotFoundError) {Handler.user_toggleable('default_tag', NAMES)}
    end

    def test_user_toggleable_rejects_non_toggleable
      assert_raise(Ginseng::ValidateError) {Handler.user_toggleable('invalid_command', NAMES)}
    end

    def test_disable
      header('Authorization', 'Bearer writable')
      post('/handler/config', {handler: 'default_tag', disable: true}.to_json, ENV_LOCALHOST)

      assert_equal(200, last_response.status)
      assert_equal({'name' => 'default_tag', 'disabled' => true}, JSON.parse(last_response.body))
    end

    def test_enable_with_string
      header('Authorization', 'Bearer writable')
      post('/handler/config', {handler: 'default_tag', disable: 'false'}.to_json, ENV_LOCALHOST)

      assert_equal(200, last_response.status)
      assert_false(JSON.parse(last_response.body)['disabled'])
    end

    def test_invalid_disable
      header('Authorization', 'Bearer writable')
      post('/handler/config', {handler: 'default_tag', disable: 'yes'}.to_json, ENV_LOCALHOST)

      assert_equal(422, last_response.status)
    end

    def test_non_toggleable
      header('Authorization', 'Bearer writable')
      post('/handler/config', {handler: 'invalid_command', disable: true}.to_json, ENV_LOCALHOST)

      assert_equal(422, last_response.status)
    end

    def test_unauthorized
      post('/handler/config', {handler: 'default_tag', disable: true}.to_json, ENV_LOCALHOST)

      assert_equal(403, last_response.status)
    end
  end
end
