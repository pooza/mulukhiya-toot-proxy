module Mulukhiya
  class SpotifyAuthContract < Contract
    params do
      # ユーザー特定は APIController の bearer 認証 (sns.account) で行うため、
      # body への token 重複は要求しない。検証するのは認可 code のみ。
      required(:code).value(:string)
    end
  end
end
