require 'rack/test'

module Mulukhiya
  # Pleroma 系（Akkoma）の絵文字リアクションで `post_reaction` を流す（段階 4・#4884）。
  #
  # ⚠ パイプライン（`/handler/pipeline/pleroma/post_reaction`）が無いと、上流へ反映した後に
  # `Event.new` が落ちて 500 になる（PR #4844 の Codex P1）。本物のコントローラと dev29 を通す。
  # ⚠ テスト環境の `ReplyReactionHandler` は `reactionable?` を見ずに返信するので、返信の有無で
  # イベントが流れたかを見る。
  class PleromaReactionTest < TestCase
    include Rack::Test::Methods

    EMOJI = '👍'.freeze

    def disable?
      return true unless Environment.pleroma?
      return true unless account
      return super
    end

    def app = PleromaController

    def test_put_and_delete
      status = account.recent_status
      path = "/api/v1/pleroma/statuses/#{status.id}/reactions/#{CGI.escape(EMOJI)}"
      with_error_handler do
        header('Host', 'localhost')
        header('Authorization', "Bearer #{account.token}")
        put(path)

        assert_equal(200, last_response.status, last_response.body)
        # `post_reaction` の `ReplyReactionHandler` が、リアクションした投稿へ返信している。
        assert_equal(status.id.to_s, account.recent_status.data[:in_reply_to_id].to_s)

        delete(path)

        assert_equal(200, last_response.status, last_response.body)
      end
    end

    private

    # ⚠ 開発モードだと例外が HTML のデバッグ画面（500）になるので、本番と同じ扱いに倒す。
    def with_error_handler
      original = [app.settings.show_exceptions, app.settings.raise_errors]
      app.set(:show_exceptions, false)
      app.set(:raise_errors, false)
      yield
    ensure
      app.set(:show_exceptions, original.first)
      app.set(:raise_errors, original.last)
    end
  end
end
