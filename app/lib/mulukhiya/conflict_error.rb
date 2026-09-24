module Mulukhiya
  # 機械可読な理由を持つ 409 (#4579)。
  #
  # ⚠⚠ **409 には「待てば通る」ものと「何度送っても通らない」ものが混ざっている。**
  # 以前はどちらも `{"error": "<日本語文>"}` だけで、クライアントは文言の一致でしか
  # 区別できなかった。**文言を推敲した瞬間にクライアントのリトライ判定が黙って壊れる**
  # ので、判定用の `code` を本文に添える。
  #
  # - `locked` — 書き込みロックの競合。**一過性**。`retry_after` 秒以内に解ける
  # - `auto_update` — 番組表の自動更新が有効。**恒久**（設定を変えるまで通らない）
  # - `duplicate_key` — 番組表のキーが既にある。**恒久**（入力が悪い）
  # - `template_limit` — 投稿テンプレートの上限。**恒久**（どれかを消すまで通らない）
  # - `duplicate_request` — Annict の同じ記録・レビューが直前に送られている。
  #   ⚠ **一過性ではない。**先の要求が成功していればロックは TTL まで残るので、
  #   待って送り直すと**二重に記録される**。先の結果を確かめてから判断する
  #
  # ⚠ `Ginseng::ConflictError` の派生にしてあるので、既存の `rescue` はそのまま効く。
  class ConflictError < Ginseng::ConflictError
    CODES = [:locked, :auto_update, :duplicate_key, :template_limit, :duplicate_request].freeze

    attr_reader :code, :retry_after

    def initialize(message, code:, retry_after: nil)
      raise ArgumentError, "unknown conflict code: #{code}" unless CODES.member?(code)
      @code = code
      @retry_after = retry_after
      super(message)
    end
  end
end
