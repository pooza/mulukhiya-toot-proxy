module Mulukhiya
  # ステータスに依らず**必ず Sentry へ上げる**印 (#4693)。
  #
  # ⚠⚠ **`report_error` はステータスだけで判断する。**`client_error?` が真なら
  # `log` 止めなので、**「403 だがこちらの設定が壊れている」型が丸ごと無音になる**。
  # #4654 の一本化で `Ginseng::CryptError`（403）が Sentry から消えたのがこれ。
  #
  # ⚠ **`report_error` の側で例外クラスを列挙しない。**列挙は #4603 / #4629 で
  # 実際に取りこぼした形（`NotFoundError` / `AuthError` が `else` へ落ちた）。
  # **「これはクライアント起因ではない」と知っているのは raise した場所だけ**なので、
  # そこで印を付けて運ぶ。`WrappedGatewayError#never_silent?` と同じ軸。
  #
  #   raise NeverSilent.mark(Ginseng::AuthError.new('...'))
  #
  # ⚠ インスタンスに `extend` するので、**新しい例外クラスを増やさない**。
  # 上流の型（`Ginseng::AuthError` など）をそのまま使え、`status` も変わらない。
  module NeverSilent
    def never_silent?
      return true
    end

    def self.mark(error)
      return error.extend(self)
    end
  end
end
