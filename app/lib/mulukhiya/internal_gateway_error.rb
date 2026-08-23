module Mulukhiya
  # モロヘイヤ**自身の内部読み**が失敗したことを表すゲートウェイエラー (#4631)。
  #
  # ⚠⚠ **クライアントの更新失敗と同じ型にしてはいけない。**#4589 の修正で
  # `create_media_update_body` に `fetch_status_source` / `fetch_status` という
  # **2 本の内部 GET** がリクエスト処理中に入ったが、その失敗が素の
  # `Ginseng::GatewayError` として `STATUS_UPDATE_SILENT_STATUSES`（401 / 404）の
  # 抑止に乗っていた。結果:
  #
  # - クライアントには「**その投稿は無い**」と読める 404 が返る
  #   （実際はモロヘイヤ側の内部読みの失敗）
  # - ⚠ silent 判定に当たるので **Sentry にも上がらず syslog 1 行だけ**
  #
  # ⚠ **ALT 編集が全ユーザーで壊れていても観測面に何も出ない**状態だった。
  # 実際 #4621 では「`/source` は 200 なのに `fetch_status` だけ落ちる」という
  # 非対称が切り分けを遅らせている。原因が変わっても同じ隠れ方を再生産するので、
  # **構造として分ける**。
  #
  # `ForeignGatewayError` と同じく `handle_gateway_error` が透過を拒み、
  # **加えて silent 判定を無条件に外す**。
  class InternalGatewayError < Ginseng::GatewayError
    # 上流のレスポンスは保つ（`e.log` に状況を残すため）が、**メッセージは
    # 差し替える**。"Bad response 404" のままだとクライアントにもログにも
    # 「対象が無い」と読めてしまい、この型を作った意味が消える。
    def self.wrap(error, label)
      wrapped = new("internal fetch failed (#{label}): #{error.message}")
      wrapped.set_backtrace(error.backtrace)
      wrapped.response = error.response if error.respond_to?(:response)
      return wrapped
    end
  end
end
