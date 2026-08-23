module Mulukhiya
  # 機能が無効・未設定で要求に応えられないことを表すエラー (503)。
  #
  # ⚠⚠ **`Ginseng::ServiceUnavailableError` は存在しない。**v5.34.0 以前から
  # `WebhookController` が 2 箇所でその名前を `raise` しており、**到達すると
  # `NameError` になっていた**（5.35.0 のリリース前レビューで検出）。
  #
  # `StandardError#status` は ginseng-core の refine で 500 を返すため、
  # `NameError` は **500 ＋「uninitialized constant」をクライアントへ返し、
  # かつ alert 側へ倒れる**。つまり:
  #
  # - `POST /mulukhiya/webhook/admin` は**署名検証より前**に此処を通るので、
  #   `agent.info.token` 未設定のサーバーでは**誰でも管理者アラートを撃てた**
  # - `features.webhook: false` のサーバーでは、`verify_webhook!` が同じ形になる
  #
  # ⚠ **`broadcastable?` を false にする。**設定が無いのは運用者が知っていれば
  # 足りる話で、外部から叩かれるたびに管理者へメール／Slack を飛ばす種類の
  # 事象ではない（#4594 と同じ判断）。
  class ServiceUnavailableError < Ginseng::Error
    def status
      return 503
    end

    def broadcastable?
      return false
    end
  end
end
