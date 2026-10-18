require 'rack/test'

module Mulukhiya
  # 書き込みのスコープを持たないトークンは、API の書き込みの要求では使わせない (#4845)。
  #
  # ⚠ 口ごとの判定は `sns.account` / `sns.account.admin?` だけなので、読み取り専用の
  # トークンでも `/config/update` や管理者向けの口が通っていた（PR #4844 の Codex P1）。
  # ⚠ DB に繋がない。トークンの持ち主とスコープは偽のサービスで決める。
  class APIWriteScopeTest < TestCase
    include Rack::Test::Methods

    # トークンの綴りで持ち主とスコープを決める偽のサービス。
    class FakeService
      attr_accessor :token

      def account
        return nil unless token
        return Struct.new(:id).new(1)
      end

      def writable_token?
        return token == 'writable'
      end
    end

    class WriteScopeProbeController < APIController
      set :raise_errors, false
      set :show_exceptions, false

      def sns_class
        return FakeService
      end

      post '/probe' do
        @renderer.message = {account: sns.account.present?}
        return @renderer.to_s
      end

      get '/probe' do
        @renderer.message = {account: sns.account.present?}
        return @renderer.to_s
      end
    end

    # ⚠ Rack::Test は GET に `rack.input` を付けないので、空の本文を明示する。
    ENV_LOCALHOST = {'HTTP_HOST' => 'localhost', input: ''}.freeze

    def app
      return WriteScopeProbeController
    end

    def test_write_scope_required
      assert(APIController.write_scope_required?('POST', '/config/update'))
      assert(APIController.write_scope_required?('DELETE', '/compose/templates/1'))
      assert(APIController.write_scope_required?('put', '/admin/program/entry/x'))
      assert_false(APIController.write_scope_required?('GET', '/config'))
      assert_false(APIController.write_scope_required?('HEAD', '/config'))
      assert_false(APIController.write_scope_required?('POST', '/account/is_cat'))
      assert_false(APIController.write_scope_required?('POST', '/nowplaying/resolve'))
      assert_false(APIController.write_scope_required?('POST', '/nowplaying/resolve-url'))
    end

    # 読み取り専用のトークンでは、書き込みの要求で持ち主が解決されない。
    def test_read_only_token_is_dropped_on_write
      header('Authorization', 'Bearer read-only')
      post('/probe', {}, ENV_LOCALHOST)

      assert_false(JSON.parse(last_response.body)['account'])
    end

    def test_writable_token_is_kept_on_write
      header('Authorization', 'Bearer writable')
      post('/probe', {}, ENV_LOCALHOST)

      assert(JSON.parse(last_response.body)['account'])
    end

    # 読み取りの要求は従来どおり。
    def test_read_only_token_is_kept_on_read
      header('Authorization', 'Bearer read-only')
      get('/probe', {}, ENV_LOCALHOST)

      assert(JSON.parse(last_response.body)['account'])
    end
  end
end
