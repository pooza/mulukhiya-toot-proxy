module Mulukhiya
  # media_catalog のページングは 1 本しか無い (#4657)。
  #
  # ⚠⚠ **`catalog` / `catalog_offset` / `catalog_from_cache` は Mastodon 側と
  # Misskey 側へ複写されていた。**差分は cursor に使う列だけ。
  # ⚠ **DB を持つ `AttachmentTest` はローカルでも CI でも omit される**ので、
  # あちらは複写の回帰を捕まえない。ここは DB 非依存で本体を直接踏む。
  class AttachmentCatalogTest < TestCase
    # `AttachmentMethods::ClassMethods` だけを持つダブル。
    # ⚠ 実モデルは `Sequel::Model(...)` なので DB 無しでは定数解決すらできない。
    class FakeAttachment
      extend AttachmentMethods::ClassMethods

      class << self
        attr_accessor :rows, :cursor_key

        def config = Config.instance
        def catalog_cursor_key = cursor_key || :id
        def build_catalog_items(rows) = rows
      end
    end

    def setup
      config['/webui/media/catalog/limit'] = 100
      FakeAttachment.cursor_key = nil
      FakeAttachment.rows = (1..10).map {|i| {id: i, status_id: 1000 + i}}
    end

    def catalog(params)
      Postgres.singleton_class.alias_method(:__orig_exec, :exec)
      Postgres.define_singleton_method(:exec) do |_name, args|
        FakeAttachment.rows.drop(args[:offset].to_i).first(args[:limit])
      end
      return FakeAttachment.catalog(params.merge(skip_cache: true))
    ensure
      Postgres.singleton_class.alias_method(:exec, :__orig_exec)
      Postgres.singleton_class.remove_method(:__orig_exec)
    end

    # 閲覧注意・CW の印 (5.41.0 のリリース前レビュー)。未認証で届く一覧なので、ぼかす材料を渡す。
    def test_plain_row_has_no_flags
      flags = FakeAttachment.catalog_flags(sensitive: false, spoiler_text: '', status_text: '本文')

      assert_equal({sensitive: false, spoiler_text: nil, body: '本文'}, flags)
    end

    def test_sensitive_row_keeps_the_body
      flags = FakeAttachment.catalog_flags(sensitive: true, spoiler_text: nil, status_text: '本文')

      assert_equal({sensitive: true, spoiler_text: nil, body: '本文'}, flags)
    end

    # ⚠⚠ CW つきは、閲覧注意の印が無くても sensitive に倒し、CW の内側の本文を出さない。
    def test_spoiler_row_hides_the_body
      flags = FakeAttachment.catalog_flags(sensitive: false, spoiler_text: 'ネタバレ', status_text: '本文')

      assert_equal({sensitive: true, spoiler_text: 'ネタバレ', body: nil}, flags)
    end

    # ⚠ 上限のページでは「続きあり」と言わない（次を引くと 422 になる）。
    def test_has_next_is_false_at_the_max_page
      config['/webui/media/catalog/max_page'] = 2

      assert_true(catalog(page: 1, limit: 3)[:has_next])
      assert_false(catalog(page: 2, limit: 3)[:has_next])
    end

    # ⚠ 巡回ワーカーは `page:` と `cursor:` を両方渡す。cursor つきでも上限のページは
    # `has_next: false` でキャッシュされること（PR #4833 の Codex P2）。
    def test_has_next_is_false_at_the_max_page_with_a_cursor
      config['/webui/media/catalog/max_page'] = 2

      assert_false(catalog(page: 2, cursor: '999', limit: 3)[:has_next])
      assert_true(catalog(cursor: '999', limit: 3)[:has_next])
    end

    # ⚠ キャッシュの鍵は上限ごとに分かれる（PR #4833 の Codex P2）。上限を変えた後に、古い境界の
    # 応答（`has_next` / `next_cursor`）を返さない。
    def test_cache_key_depends_on_the_max_page
      config['/webui/media/catalog/max_page'] = 3
      key = FakeAttachment.catalog_cache_key(2, 0)
      storage = MediaCatalogStorage.new
      storage.set(key, {items: [], has_next: true, page: 2})

      assert_true(FakeAttachment.send(:catalog_from_cache, {page: 2})[:has_next])

      config['/webui/media/catalog/max_page'] = 2

      assert_not_equal(key, FakeAttachment.catalog_cache_key(2, 0))
      assert_nil(FakeAttachment.send(:catalog_from_cache, {page: 2}))
    ensure
      storage&.unlink(key)
    end

    # ⚠⚠ **#4632 の回帰。**`has_next` を見るために取得件数へ +1 しているので、
    # その `limit` を OFFSET の基準にも使うと**ページごとに 1 件抜ける**。
    def test_offset_is_computed_from_the_page_width
      assert_equal(0, FakeAttachment.catalog_offset(page: 1, limit: 100))
      assert_equal(100, FakeAttachment.catalog_offset(page: 2, limit: 100))
      assert_equal(200, FakeAttachment.catalog_offset(page: 3, limit: 100))
    end

    # cursor 指定時は OFFSET を使わない（キーセットページング）。
    def test_offset_is_zero_for_cursor_and_pageless
      assert_equal(0, FakeAttachment.catalog_offset(cursor: '123', page: 5, limit: 10))
      assert_equal(0, FakeAttachment.catalog_offset(limit: 10))
    end

    # ⚠ **境界の 1 件が消えないこと**を実際のページ送りで見る。
    def test_pages_do_not_drop_a_row_at_the_boundary
      first = catalog(page: 1, limit: 3)
      second = catalog(page: 2, limit: 3)

      assert_equal([1, 2, 3], first[:items].map {|r| r[:id]})
      assert_equal([4, 5, 6], second[:items].map {|r| r[:id]})
      assert_true(first[:has_next])
    end

    # ⚠⚠ **2 ファイルを分けていた唯一の差分。**Mastodon は `media_attachments.id`、
    # Misskey は SQL が note_id ベースで unnest を展開するため `status_id`。
    def test_next_cursor_uses_the_subclass_key
      assert_equal('3', catalog(page: 1, limit: 3)[:next_cursor])

      FakeAttachment.cursor_key = :status_id

      assert_equal('1003', catalog(page: 1, limit: 3)[:next_cursor])
    end

    # 最終ページでは `has_next` が false になり `next_cursor` を付けない。
    def test_last_page_has_no_cursor
      result = catalog(page: 4, limit: 3)

      assert_equal([10], result[:items].map {|r| r[:id]})
      assert_false(result[:has_next])
      assert_nil(result[:next_cursor])
    end

    # `:page` は呼び出し側が渡したときだけエコーする (#4516)。
    def test_page_is_echoed_only_when_given
      assert_equal(2, catalog(page: 2, limit: 3)[:page])
      assert_nil(catalog(limit: 3)[:page])
    end

    # 実装しなければ落ちる。⚠ 静かに `:id` へ倒すと Misskey 側が壊れたまま通る。
    def test_cursor_key_is_required
      klass = Class.new {extend AttachmentMethods::ClassMethods}

      assert_raise(NotImplementedError) {klass.catalog_cursor_key}
    end

    # ⚠ **`include` だけでクラスメソッドが生えること (#4698)。**`FakeAttachment` は
    # `extend ClassMethods` を直に書いているので、実モデルが頼る `self.included` の
    # 配線は見ていない。実モデルそのものは DB 無しで定数解決できないので、
    # 実クラスでの疎通は `AttachmentTest#test_catalog_is_wired_on_the_real_class`。
    def test_include_wires_the_class_methods
      klass = Class.new {include AttachmentMethods}

      assert_respond_to(klass, :catalog)
      assert_respond_to(klass, :catalog_offset)
      assert_respond_to(klass, :catalog_from_cache)
    end
  end

  # 複写が戻っていないことを構造で押さえる (#4657)。
  #
  # ⚠ **DB を持つテストは omit されるので、複写が生えても気づけない。**
  class AttachmentCatalogNotDuplicatedTest < TestCase
    SHARED = ['catalog', 'catalog_offset', 'catalog_from_cache'].freeze

    TARGETS = [
      'app/lib/mulukhiya/model/mastodon/attachment.rb',
      'app/lib/mulukhiya/model/misskey/attachment.rb',
    ].freeze

    def test_models_do_not_redefine_the_shared_catalog_methods
      offenders = TARGETS.flat_map do |path|
        source = File.read(File.join(Environment.dir, path))
        SHARED.filter_map do |name|
          next unless /^\s*def self\.#{name}\b/.match?(source)
          "#{File.basename(path)} が #{name} を再定義している"
        end
      end

      assert_equal([], offenders, 'AttachmentMethods::ClassMethods へ寄せる (#4657)')
    end

    # ⚠ **実モデルが共有側を取り込んでいること (#4698)。**外れると `catalog` が
    # 生えず、DB を持つテストは omit されるので気づけない。
    def test_models_include_the_shared_module
      TARGETS.each do |path|
        source = File.read(File.join(Environment.dir, path))

        assert_match(/^\s*include AttachmentMethods$/, source, File.basename(path))
      end
    end

    # ⚠ **共有側に実体があることも確かめる。**両方から消えただけの状態を
    # 「重複が無い」と読まないため。
    def test_shared_module_owns_them
      SHARED.each do |name|
        assert_true(
          AttachmentMethods::ClassMethods.method_defined?(name.to_sym, false),
          "AttachmentMethods::ClassMethods が #{name} を持つべき",
        )
      end
    end
  end
end
