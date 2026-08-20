module Mulukhiya
  class AttachmentTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return super
    end

    def setup
      return if disable?
      # catalog が空（harness 等 media 未 seed）でも setup をクラッシュさせず nil に倒す。
      # 各テストは `return unless @attachment` で本来 no-op 設計。
      item = attachment_class.catalog[:items].first
      @attachment = item && attachment_class[item[:id]]
    end

    test 'テスト用メディアファイルの有無' do
      # 実 DB には media が存在するので非 nil を検証する。harness 等 media 未 seed の
      # 環境では構造的に green にできないため precondition 明示 omit（silent skip ではない）。
      # harness 側の seed 追加は chubo2#64。
      omit('テスト用メディア未 seed（chubo2#64）') unless @attachment

      assert_not_nil(@attachment)
    end

    def test_to_h
      return unless @attachment
      h = @attachment.to_h

      assert_includes(h, :id)
      assert_kind_of(Hash, h)
      assert_kind_of([String, NilClass], h[:created_at])
      assert_kind_of([Float, NilClass], h[:duration])
      assert_kind_of(String, h[:file_name])
      assert_kind_of(String, h[:file_size_str])
      assert_kind_of(String, h[:mediatype])
      assert_kind_of([String, NilClass], h[:pixel_size])
      assert_kind_of([String, NilClass], h[:thumbnail_url])
      assert_kind_of(String, h[:type])
      assert_kind_of(String, h[:url])
    end

    def test_name
      return unless @attachment

      assert_kind_of(String, @attachment.name)
      assert_predicate(@attachment, :present?)
    end

    def test_date
      return unless @attachment

      assert_kind_of([Time, NilClass], @attachment.date)
    end

    def test_size
      return unless @attachment

      assert_predicate(@attachment.size, :positive?)
    end

    def test_size_str
      return unless @attachment

      assert_kind_of(String, @attachment.size_str)
    end

    def test_width
      return unless @attachment

      assert_kind_of([Integer, NilClass], @attachment.width)
    end

    def test_height
      return unless @attachment

      assert_kind_of([Integer, NilClass], @attachment.height)
    end

    def test_description
      return unless @attachment

      assert_kind_of([String, NilClass], @attachment.description)
    end

    def test_meta
      return unless @attachment

      assert_kind_of(Hash, @attachment.meta)
    end

    def test_uri
      return unless @attachment

      assert_kind_of(Ginseng::URI, @attachment.uri)
      assert_predicate(@attachment.uri, :absolute?)
    end

    def test_thumbnail_uri
      return unless @attachment

      assert_kind_of(Ginseng::URI, @attachment.thumbnail_uri)
      assert_predicate(@attachment.thumbnail_uri, :absolute?)
    end

    def test_feed
      return unless @attachment

      assert_kind_of(Hash, attachment_class.feed.first)
    end

    def test_catalog
      return unless @attachment
      result = attachment_class.catalog

      assert_kind_of(Hash, result)
      assert_kind_of(Array, result[:items])
      assert_kind_of(Hash, result[:items].first)
      assert_includes([true, false], result[:has_next])

      # `:page` は「呼び出し側が渡したページ番号のエコー」で、既定値 1 の補完は
      # API 境界の MediaCatalogQueryService#normalize が持つ（`cursor` 指定時は
      # 付けない、という docs/api.md の仕様もそちらで担保している）。モデルを直接
      # 叩く経路では渡さない限り付かないので、渡して確かめる (#4516)。
      assert_equal(1, attachment_class.catalog(page: 1)[:page])

      result = attachment_class.catalog(only_person: 1)

      assert_kind_of(Hash, result[:items].first)
    end

    def test_cursor_pagination
      assert_boolean(attachment_class.cursor_pagination?)
      assert_equal(!Environment.misskey_type?, attachment_class.cursor_pagination?)
    end

    # ⚠ **ページ送りの継ぎ目 (#4393)。**media_catalog はローカルアカウント駆動の
    # LATERAL merge で、**アカウントごとに top-N を取ってから全体の top-N を採る**。
    # 内側の LIMIT が足りないと、境界のレコードが**黙って落ちる**。
    def test_catalog_cursor_has_no_overlap
      return unless @attachment
      first = attachment_class.catalog(limit: 2, skip_cache: true)
      # ⚠ harness は media がほぼ test_account 持ちで、除外すると 1 件しか残らない。
      # silent skip にせず precondition を明示する（seed の追加は chubo2#64）。
      omit('ページ送りを検証できるだけの media が未 seed（chubo2#64）') unless first[:has_next]
      following = attachment_class.catalog(limit: 2, cursor: first[:next_cursor], skip_cache: true)
      first_ids = first[:items].map {|v| v[:id]}
      following_ids = following[:items].map {|v| v[:id]}

      assert_equal(first_ids.sort.reverse, first_ids)
      assert_empty(first_ids & following_ids)
      assert_operator(following_ids.max, :<, first_ids.min) if following_ids.present?
    end

    # ⚠ **OFFSET とカーソルが同じ並びを指すこと。**LATERAL の内側 LIMIT は
    # `limit + offset` でないと、2 ページ目以降で件数が足りなくなる。
    def test_catalog_page_offset_matches_cursor
      return unless @attachment
      first = attachment_class.catalog(limit: 2, skip_cache: true)
      omit('ページ送りを検証できるだけの media が未 seed（chubo2#64）') unless first[:has_next]
      by_cursor = attachment_class.catalog(limit: 2, cursor: first[:next_cursor], skip_cache: true)
      by_offset = attachment_class.catalog(limit: 2, page: 2, skip_cache: true)

      assert_equal(by_cursor[:items].map {|v| v[:id]}, by_offset[:items].map {|v| v[:id]})
    end

    # only_person は絞り込みなので、結果は常に全体の部分集合。
    def test_catalog_only_person_is_subset
      return unless @attachment
      all_ids = attachment_class.catalog(limit: 10, skip_cache: true)[:items].map {|v| v[:id]}
      person_ids = attachment_class.catalog(limit: 10, only_person: 1, skip_cache: true)
        .fetch(:items).map {|v| v[:id]}

      assert_empty(person_ids - all_ids)
    end
  end
end
