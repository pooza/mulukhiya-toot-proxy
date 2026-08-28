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
  class InternalGatewayError < WrappedGatewayError
    # ⚠ 包み直し自体は `WrappedGatewayError` が持つ (#4657)。この型が変えるのは
    # **メッセージと silent 抑止の 2 点だけ**。
    #
    # "Bad response 404" のままだとクライアントにもログにも「対象が無い」と
    # 読めてしまい、この型を作った意味が消える。
    def self.wrapped_message(error, label)
      return "internal fetch failed (#{label}): #{error.message}"
    end

    # ⚠⚠ **内部読みの失敗は無条件に alert する (#4631)。**モロヘイヤ自身の
    # `fetch_status` 等が落ちているのはクライアント起因ではないので、
    # `silent_statuses` に 404 が入っていても抑止してはいけない。
    # 抑止すると「ALT 編集が全ユーザーで壊れている」が syslog 1 行に消える。
    def never_silent?
      return true
    end

    # ⚠⚠ **内部メソッド名と上流ステータスを外へ出さない (#4657)。**従来は
    # `{"error":"internal fetch failed (fetch_status): Bad response 404"}` を
    # そのまま返していた。`handle_gateway_error` は別の分岐で
    # 「モロヘイヤ内部の例外メッセージを混ぜてはいけない（内部情報の露出）」と
    # 明記しており、方針が揃っていなかった。
    #
    # ⚠ **ラベルと上流のメッセージは `message` に残る**ので、`e.alert` /
    # `e.log` から失われることはない。**クライアントに渡す面だけを絞る。**
    # ⚠ **文言は従来どおり小文字のまま。**api.md が「`internal fetch failed` を
    # 『その投稿は無い』と読まないこと」と書いており、クライアントが目印として
    # 使いうる。**落とすのは括弧の中身（ラベルと上流ステータス）だけ。**
    CLIENT_MESSAGE = 'internal fetch failed'.freeze

    def client_message
      return CLIENT_MESSAGE
    end
  end
end
