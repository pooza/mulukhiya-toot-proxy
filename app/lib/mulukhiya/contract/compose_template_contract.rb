module Mulukhiya
  # 投稿テンプレート (#4457) の作成・更新の入力検証。`name` は必須・非空、`body` は
  # 必須だが空文字は許容（capsicum の設計で「本文だけ空のテンプレ」を認める）、
  # `cw` は任意。件数上限は状態依存のため ComposeTemplateContainer 側で検証する。
  class ComposeTemplateContract < Contract
    MAX_NAME_SIZE = 100
    MAX_BODY_SIZE = 5000
    MAX_CW_SIZE = 200

    params do
      required(:name).value(:string, max_size?: MAX_NAME_SIZE)
      required(:body).value(:string, max_size?: MAX_BODY_SIZE)
      optional(:cw).maybe(:string, max_size?: MAX_CW_SIZE)
    end

    rule(:name) do
      key.failure('テンプレート名が空欄です。') if value.to_s.strip.empty?
    end
  end
end
