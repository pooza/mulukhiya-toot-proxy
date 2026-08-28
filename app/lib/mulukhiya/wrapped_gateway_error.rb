module Mulukhiya
  # 上流のエラーを「どこ由来か」で包み直すゲートウェイエラーの基底 (#4657)。
  #
  # ⚠⚠ **クライアントへ透過してよいのは自分の上流 (Mastodon / Misskey) が返した
  # ものだけ** (#4480)。それ以外の由来——引用元の他人のサーバー
  # (`ForeignGatewayError`) と、モロヘイヤ自身の内部読み
  # (`InternalGatewayError`)——は透過を拒む。
  #
  # ⚠ **判定はクラスの列挙でしない。**従来は `handle_gateway_error` が
  # `error.is_a?(ForeignGatewayError) || error.is_a?(InternalGatewayError)` と
  # 2 つ並べていた。**#4629 で否定したばかりの形がエラー型側に残っていた**ので、
  # 「透過を拒む」は `is_a?(WrappedGatewayError)` 1 本にする。3 つ目の由来が
  # 増えても、この基底を継げば自動的に拒まれる。
  class WrappedGatewayError < Ginseng::GatewayError
    # 上流のレスポンスは保つ（`e.log` に状況を残すため）。
    #
    # ⚠ `wrap` は `ForeignGatewayError` と `ForeignGatewayError` で 4 行同一だった。
    # 差分は**メッセージの作り方だけ**なので、そこだけ `wrapped_message` に切る。
    def self.wrap(error, label = nil)
      wrapped = new(wrapped_message(error, label))
      wrapped.set_backtrace(error.backtrace)
      wrapped.response = error.response if error.respond_to?(:response)
      return wrapped
    end

    # 既定は上流のメッセージのまま。
    def self.wrapped_message(error, _label)
      return error.message
    end

    # Sentry alert の抑止 (`silent_statuses` / `silent_codes`) を無条件に外すか。
    #
    # ⚠ **透過拒否とは別の軸。**「クライアントへ返さない」と「観測面から
    # 消さない」は同じではないので、マーカーを分ける。
    def never_silent?
      return false
    end

    # クライアントへ返す文言 (#4657)。
    #
    # ⚠⚠ **`message` をそのまま返すと内部情報が外へ出る型がある。**
    # ログには詳細を残したいが、クライアントへ返すのは別物。既定は同じ。
    def client_message
      return message
    end
  end
end
