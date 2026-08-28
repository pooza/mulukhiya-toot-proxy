module Mulukhiya
  # HTTP ステータスの分類 (#4657)。
  #
  # ⚠⚠ **同じ「4xx か」の判定が 3 通りの書き方で散っていた。**
  # `Controller#client_error?` は `status.to_i.between?(400, 499)`、
  # `MastodonController#internal_failure?` は同じ式の否定、
  # `SpotifyUserService` は `source_status&.between?(400, 499)`。
  # ⚠ **マジックレンジの複写は #4603 / #4629 / #4654 と同じ形**で、
  # どれか 1 つを直したときに残りが取り残される。
  #
  # ⚠ **どの属性（`status` か `source_status` か）を渡すかは呼び側の判断。**
  # ここはレンジだけを持つ。渡すものを間違えると意味が変わるので、
  # 呼び側に「なぜその属性か」を書く。
  module HTTPStatus
    CLIENT_ERROR_RANGE = (400..499)

    # ⚠ **nil は 4xx ではない。**`source_status` は接続失敗で nil になり、
    # それは「クライアント起因」ではなく上流かこちらの問題。
    def self.client_error?(status)
      return CLIENT_ERROR_RANGE.cover?(status.to_i)
    end
  end
end
