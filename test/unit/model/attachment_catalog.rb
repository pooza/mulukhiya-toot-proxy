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
