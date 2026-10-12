module Mulukhiya
  class MediaCatalogQueryService
    include Package

    # クエリへ渡してよいパラメータ。
    #
    # ⚠⚠ **ここで絞る（5.41.0 のリリース前レビュー）。**`Contract#exec` はエラーを返すだけで
    # 絞らないので、以前は要求のパラメータがそのまま `catalog` へ届いていた。未認証の
    # `?skip_cache=1` でキャッシュを飛ばせ、`?limit=5` / `?rule=x` は型が合わず 500 になる
    # （`limit` / `rule` / `skip_cache` は内部の呼び出しだけが使う）。
    ALLOWED_PARAMS = [:page, :cursor, :q, :only_person].freeze

    def initialize(attachment_class: Environment.attachment_class)
      @attachment_class = attachment_class
    end

    def call(params)
      return @attachment_class.catalog(normalize(params))
    end

    private

    def normalize(params)
      params = ALLOWED_PARAMS.to_h {|key| [key, params[key] || params[key.to_s]]}.compact
      # ⚠ cursor があるときは `page` を捨てる（文書どおり無視する）。残すと文字列のまま
      # `catalog` へ届き、ページの上限の判定に掛かる（PR #4833 の Codex P2）。
      if params[:cursor]
        params.delete(:page)
      else
        params[:page] = (params[:page] || 1).to_i
      end
      params[:only_person] = (params[:only_person] || 0).to_i.zero? ? 0 : 1
      if params[:q].to_s.empty?
        params.delete(:q)
      else
        params[:rule] = SearchRule.new(params[:q])
      end
      return params
    end
  end
end
