module Mulukhiya
  # 自分の投稿の一覧の検索（`q`）とページ送り（#4900 で Pleroma 系にも足した）。
  #
  # ⚠ 投稿の中身はテスト用アカウントの既存の投稿に依る。足りないときは黙って抜ける。
  class AccountStatusesPagingTest < TestCase
    def disable?
      return true unless controller_class.account_timeline?
      return true unless account
      return super
    end

    def test_page
      first = account.statuses(limit: 3, page: 1).pluck(:id)
      second = account.statuses(limit: 3, page: 2).pluck(:id)
      return if second.empty?

      assert_empty(first & second)
    end

    def test_search
      return unless status = account.statuses(limit: 1).first
      # ⚠ `to_h` の中身は系ごとに違う（Pleroma 系は API の形で `text` を持たない）。共通の `body` から拾う。
      return unless word = status[:body].to_s.scan(/[[:alnum:]]{2,}/).first

      hits = account.statuses(rule: SearchRule.new(word), limit: 50).pluck(:id)
      misses = account.statuses(rule: SearchRule.new("-#{word}"), limit: 50).pluck(:id)

      assert_includes(hits, status[:id])
      assert_not_include(misses, status[:id])
    end
  end
end
