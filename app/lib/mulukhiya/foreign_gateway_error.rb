module Mulukhiya
  # 引用元 = **他人のサーバー**の取得に失敗したことを表すゲートウェイエラー (#4537)。
  #
  # ⚠ **これをクライアントへ透過してはいけない。**#4480 の透過は「自分の上流
  # (Mastodon / Misskey) が返した理由をそのままクライアントへ返す」ためのもので、
  # 引用 URL の先——モロヘイヤと何の関係も無い他人のサーバー——のステータスと
  # ボディを返す口ではない。透過すると、クライアントから見て「モロヘイヤの上流が
  # そう言っている」ように読めてしまう。
  #
  # 現状 `NoteURI#to_md` / `TootURI#to_md` の呼び出し元はいずれも degrade する
  # （ClippingWorker は生 URL へ、`Status#to_md` はローカルのテンプレートへ）ので
  # リクエスト層までは届かない。**この型は「届いたときに透過されない」ことを
  # 担保するためのもの**で、`Controller#handle_gateway_error` が明示的に弾く。
  class ForeignGatewayError < Ginseng::GatewayError
    # 上流のレスポンスを保ったまま「他人のサーバー由来」に印を付け替える。
    # レスポンスを捨てないのは、ログ (`e.log`) に上流の状況を残すため。
    def self.wrap(error)
      wrapped = new(error.message)
      wrapped.set_backtrace(error.backtrace)
      wrapped.response = error.response if error.respond_to?(:response)
      return wrapped
    end
  end
end
