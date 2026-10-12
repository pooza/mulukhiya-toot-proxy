module Mulukhiya
  class MediaListContract < Contract
    params do
      optional(:page).value(:integer).value(gt?: 0)
      optional(:cursor).value(:string)
      optional(:q).value(:string)
      optional(:only_person).value(:integer)
    end

    # ⚠ cursor は ID（Mastodon は数字・Misskey は英数字）。それ以外はクエリへ渡さない。
    # Mastodon では bigint への変換に失敗して 500 になり、未認証の要求で alert が鳴る
    # （5.41.0 のリリース前レビュー）。
    rule(:cursor) do
      next unless key?
      pattern = Environment.mastodon_type? ? /\A\d+\z/ : /\A[0-9A-Za-z]+\z/
      key.failure('形式が正しくありません。') unless value.match?(pattern)
    end
  end
end
