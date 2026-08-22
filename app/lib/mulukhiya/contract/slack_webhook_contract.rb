module Mulukhiya
  class SlackWebhookContract < Contract
    params do
      required(:digest).value(:string)
      required(:text).value(:string)
      # 公開範囲はリクエストごとに指定できる (#4599)。未指定ならアカウント設定
      # (/webhook/visibility) の既定に倒れる。
      #
      # ⚠ **値の妥当性はここで見ない。**未知の値は Parser.visibility_name が
      # public へ丸めるので、契約で弾くと「既定へ倒す」設計と二重管理になる。
      # ⚠ **maybe にしてあるのは後方互換のため。**`"visibility": null` を送っていた
      # クライアントが、この項目を足したことで 422 になるのを避ける。
      optional(:visibility).maybe(:string)
    end
  end
end
