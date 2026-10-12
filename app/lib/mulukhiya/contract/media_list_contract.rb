module Mulukhiya
  class MediaListContract < Contract
    params do
      optional(:page).value(:integer).value(gt?: 0)
      optional(:cursor).value(:string)
      optional(:q).value(:string)
      optional(:only_person).value(:integer)
    end

    DEFAULT_MAX_PAGE = 50

    # ⚠⚠ **ページに上限を置く（5.41.0 のリリース前レビュー）。**未認証で届き、深いページほど
    # 重い（OFFSET ぶんまで各ローカルアカウントから引く）。上限が無いと `?page=1000000` で
    # 全件を引いて並べさせられる（2026-05-19 の接続プール枯渇と同じ経路）。
    # ⚠ cursor つきの要求では `page` は無視されるので、上限も見ない（PR #4833 の Codex P2）。
    # ページ番号を数え続けながら `next_cursor` を辿るクライアントを 422 にしない。
    rule(:page) do
      next unless key?
      next if values[:cursor]
      max = (Config.instance['/webui/media/catalog/max_page'] rescue nil) || DEFAULT_MAX_PAGE
      key.failure("#{max} ページまでです。") if value > max
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
