require 'rack/test'

module Mulukhiya
  # 最上位 `error` ブロックが 4xx を alert に上げない (#4654)。
  #
  # ⚠⚠ **ここはルートのローカル rescue をすり抜けた例外の最後の受け皿**で、
  # どのルートから来たかは分からない。従来は無条件 `e.alert` だったので、
  # 4xx でも Sentry ＋ `Event.new(:alert)`（slack / line / mail）に落ちていた。
  class TopLevelErrorHandlerTest < TestCase
    include Rack::Test::Methods

    # ルート側で rescue しないコントローラ。`error do` は Controller から継承する。
    class ErrorProbeController < Controller
      # ⚠ Sinatra は環境によって `raise_errors` / `show_exceptions` の既定が変わり、
      # true だと `error` ブロックへ入る前に例外を投げ直す。テストの意図は
      # **error ブロックのふるまい**なので、両方を明示的に落として固定する。
      set :raise_errors, false
      set :show_exceptions, false

      class << self
        attr_accessor :probe
      end

      get '/probe' do
        raise self.class.probe
      end
    end

    def app = ErrorProbeController

    # ⚠ Sinatra のホスト認可で 403 になるので Host を明示する。
    def probe(error)
      ErrorProbeController.probe = spy(error)
      # ⚠ **Rack 3 では `rack.input` が任意**で、rack-test は省略する。省略すると
      # `before` の `request.body.read` が `NoMethodError` で落ち、before ごと
      # 飛んでしまう（本番の Puma は必ず入れるのでテスト固有）。明示して埋める。
      get('/probe', {}, 'HTTP_HOST' => 'localhost', 'rack.input' => StringIO.new(''))
      return ErrorProbeController.probe
    end

    def test_client_error_reaching_top_level_is_not_alerted
      [
        Ginseng::AuthError.new('Unauthorized'),
        Ginseng::NotFoundError.new('Not Found'),
        Ginseng::ValidateError.new('invalid'),
      ].each do |raw|
        error = probe(raw)

        assert_equal([:log], error.mulukhiya_calls, "#{raw.class} は log であるべき")
      end
    end

    # モロヘイヤ自身のバグは黙らせない。
    def test_server_error_reaching_top_level_is_alerted
      error = probe(Ginseng::GatewayError.new('Bad response 502'))

      assert_equal([:alert], error.mulukhiya_calls)
    end

    def test_status_is_still_rendered
      probe(Ginseng::NotFoundError.new('Not Found'))

      assert_equal(404, last_response.status)
    end

    private

    def spy(error)
      calls = []
      error.define_singleton_method(:mulukhiya_calls) {calls}
      error.define_singleton_method(:alert) {calls << :alert}
      error.define_singleton_method(:log) {calls << :log}
      return error
    end
  end

  # コントローラ層の rescue に `e.log` / `e.alert` の直書きを残さない (#4654)。
  #
  # ⚠⚠ **#4603 / #4629 / #4654 はいずれも「同じ判定の複写が片方だけ取り残された」形**で
  # 起きている。複写が増えていないことをテストで押さえる。目視のレビューでは
  # 3 回続けて漏れた。
  class ControllerRescueConsolidationTest < TestCase
    # 現地に理由が書いてある唯一の例外 (#4603)。署名検証の失敗 (`AuthError`) を
    # 黙らせたくないので、4xx でも alert するのが正しい。
    #
    # ⚠⚠ **ファイル単位で許すと同じファイルの他ルートまで素通しになる**（Codex P2）。
    # `webhook_controller.rb` には `post '/:digest'` / `get '/:digest'` も居て、
    # そちらが `e.alert` に戻されても気づけなくなる。**ルート単位で固定する。**
    ALLOWED = {'webhook_controller.rb' => {"post '/admin'" => 'e.alert'}}.freeze

    DIRECT_CALL = /\A(e\.log|e\.alert|e\.status < 500 \? e\.log : e\.alert)\z/

    def test_no_direct_log_or_alert_in_bare_rescue
      offenders = controller_sources.flat_map do |path|
        name = File.basename(path)
        bare_rescues(path).filter_map do |scope, lineno, body|
          next unless DIRECT_CALL.match?(body)
          next if ALLOWED.dig(name, scope) == body
          "#{name}:#{lineno} (#{scope}) #{body}"
        end
      end

      assert_equal([], offenders, 'report_error(e) に寄せる (#4654)')
    end

    # ⚠ **allowlist が腐らないようにする。**#4603 の意図した例外が消えたら
    # allowlist ごと落とす。
    def test_allowlist_is_still_live
      ALLOWED.each do |name, routes|
        found = bare_rescues("#{Environment.dir}/app/lib/mulukhiya/controller/#{name}")
          .to_h {|scope, _lineno, body| [scope, body]}

        routes.each do |scope, body|
          assert_equal(body, found[scope], "#{name} の #{scope} は allowlist と一致するべき")
        end
      end
    end

    # ⚠ allowlist に入れていない同居ルートが本当に検査対象になっているか。
    # **これが無いと「ルート単位に絞った」という主張自体が検証されない。**
    def test_sibling_routes_are_still_inspected
      scopes = bare_rescues("#{Environment.dir}/app/lib/mulukhiya/controller/webhook_controller.rb")
        .map(&:first)

      assert_include(scopes, "post '/:digest'")
      assert_include(scopes, "get '/:digest'")
    end

    private

    def controller_sources
      dir = "#{Environment.dir}/app/lib/mulukhiya"
      return ["#{dir}/controller.rb"] + Dir.glob("#{dir}/controller/*.rb")
    end

    # 素の `rescue => e` を [囲みスコープ, 行番号, 本体先頭] で返す。
    # ⚠ 型付きの `rescue Ginseng::GatewayError => e` は対象外。上流の 4xx をそのまま
    # 透過する等、ステータスでは決められない判断が現地にある。
    def bare_rescues(path)
      lines = File.readlines(path)
      return lines.each_with_index.filter_map do |line, i|
        next unless /^\s*rescue\s*=>\s*e\s*$/.match?(line)
        rest = lines[(i + 1)..]
        body = rest.find {|l| l.strip.present? && !l.strip.start_with?('#')}
        next unless body
        [scope_of(lines, i), rest.index(body) + i + 2, body.strip]
      end
    end

    # 直近の Sinatra ルートまたは `def` / ブロック名。⚠ **ルートを跨いで遡らない**よう、
    # どちらか先に当たったほうで止める。
    def scope_of(lines, index)
      i = index
      until i.negative?
        case lines[i]
        when /^\s*(get|post|put|delete|patch) (['"])(.+?)\2 do$/ then return "#{::Regexp.last_match(1)} '#{::Regexp.last_match(3)}'"
        when /^\s*def (\S+)/ then return "def #{::Regexp.last_match(1)}"
        when /^\s*(before|after|error|not_found) do/ then return "#{::Regexp.last_match(1)} block"
        end
        i -= 1
      end
      return '(toplevel)'
    end
  end
end
