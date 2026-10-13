module Mulukhiya
  # media_catalog のクエリが載せる範囲 (5.41.0 のリリース前レビュー)。
  #
  # 🔴 **未認証で届くサーバー横断の一覧。**載せるのは公開の投稿だけで、未収載
  # （Misskey ではホーム公開）は載せない。RSS はぼかせないので、閲覧注意・CW つきも外す。
  # ⚠ DB は使わない。テンプレートの文面を両系とも直に見る（片方だけ直す、を防ぐ）。
  class MediaCatalogQueryScopeTest < TestCase
    def test_mastodon_lists_public_statuses_only
      sql = source(:mastodon)

      assert_include(sql, '(statuses.visibility = 0)')
      assert_not_include(sql, 'statuses.visibility < 2')
    end

    def test_misskey_lists_public_notes_only
      sql = source(:misskey)

      assert_include(sql, 'visibility_name(:public)')
      assert_not_include(sql, 'visibility_name(:unlisted)')
    end

    def test_both_return_the_flags
      assert_include(source(:mastodon), 'picked.sensitive')
      assert_include(source(:mastodon), 'picked.spoiler_text')
      assert_include(source(:misskey), 'AS sensitive')
      assert_include(source(:misskey), 'AS spoiler_text')
    end

    # ⚠ `safe` は feed（RSS）だけが渡す。
    def test_both_have_the_safe_filter
      [:mastodon, :misskey].each do |type|
        assert_match(/params\[:safe\]/, source(type))
      end
      assert_include(source(:mastodon), '(statuses.sensitive = false)')
      assert_include(source(:misskey), '(drive_file."isSensitive" = false)')
    end

    # 🔴 Misskey は 1 つのノートに添付が複数ある。`note_id` だけで並べて切ると、ページの境目に
    # 当たったノートの残りの添付がどのページにも出ない (#4325 / #4375)。
    def test_misskey_orders_and_cuts_by_note_and_file_order
      sql = source(:misskey)

      assert_include(sql, 'WITH ORDINALITY AS file(file_id, file_order)')
      assert_match(/ORDER BY\s+note_file\.note_id DESC,\s+note_file\.file_order ASC/, sql)
      assert_include(sql, 'note_file.file_order <= <%= cursor_order.to_i %>')
      # ⚠ cursor は検証済みでも素で埋めない。
      assert_not_include(sql, "'<%= params[:cursor] %>'")
    end

    def test_feed_asks_for_the_safe_set
      [:mastodon, :misskey].each do |type|
        model = File.read(File.join(Environment.dir, "app/lib/mulukhiya/model/#{type}/attachment.rb"))

        assert_include(model, 'safe: true')
      end
    end

    private

    def source(type)
      return File.read(File.join(Environment.dir, "app/query/#{type}/media_catalog.sql.erb"))
    end
  end
end
