module Mulukhiya
  class SpotifyAuthContract < Contract
    params do
      # ユーザー特定は APIController の bearer 認証 (sns.account) で行うため、
      # body への token 重複は要求しない。
      required(:code).value(:string)
      # ⚠⚠ **`state` は必須 (#4414)。**認可レスポンスの取り違え・横取り（CSRF）への
      # 対策。⚠ `GET /spotify/oauth_uri` が返した URI の `state` をそのまま戻す。
      # ⚠ **capsicum 側の code 捕捉フローに往復の追加が要る**（pooza/capsicum#570）。
      required(:state).value(:string)
    end
  end
end
