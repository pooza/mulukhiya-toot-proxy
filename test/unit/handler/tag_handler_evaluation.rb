# ファイル名を `_handler` で終わらせないこと。TestCase.load は `*_handler` の
# ケースを `Handler.create(name).disable?` でゲートするため、DB の無い環境
# （CI を含む）ではファイルごと読み込まれず、この回帰テストが黙って走らなくなる。
module Mulukhiya
  class TagHandlerTest < TestCase
    # 評価回数だけを数えるハンドラ。TagContainer は normalize で
    # TaggingHandler.normalize_rules（DB）を引くため、ここでは素の Set を使って
    # DB 非依存にする（CI でも走らせるため）。
    class CountingTagHandler < TagHandler
      attr_reader :addition_count, :removal_count

      def initialize(params = {})
        super
        @addition_count = 0
        @removal_count = 0
      end

      def executable?
        return true
      end

      def addition_tags
        @addition_count += 1
        return Set['addition']
      end

      def removal_tags
        @removal_count += 1
        return Set['removal']
      end
    end

    # params は Event#handlers が全ハンドラへ渡す同一の Hash に相当する。
    # 共有のスコープを検証するため、新しい Hash を作らず渡された物を使う。
    def create_handler(params = {})
      params[:sns] ||= Struct.new(:account).new(nil)
      params[:reporter] ||= Struct.new(:tags).new(Set['removal'])
      return CountingTagHandler.new(params)
    end

    # #4494 の回帰テスト。`result.push(addition_tags:)` の短縮記法が同名の
    # ローカルが無ければメソッド呼び出しになるため、素直に書くと if の分と
    # 合わせて 1 投稿につき 3 回ずつ評価されていた。これらは純粋な getter では
    # なく Redis 読み・辞書スイープ・リモート照会を伴う。
    def test_handle_pre_toot_evaluates_tags_once
      handler = create_handler
      handler.handle_pre_toot(status_field => 'プリキュア')

      assert_equal(1, handler.addition_count)
      assert_equal(1, handler.removal_count)
    end

    def test_handle_pre_toot_applies_tags
      handler = create_handler
      handler.handle_pre_toot(status_field => 'プリキュア')

      assert_equal(Set['addition'], handler.tags)
      assert_equal([{addition_tags: Set['addition']}, {removal_tags: Set['removal']}], handler.result.to_a)
    end

    def test_handle_pre_toot_skips_when_not_executable
      handler = create_handler
      def handler.executable?
        return false
      end
      handler.handle_pre_toot(status_field => 'プリキュア')

      assert_equal(0, handler.addition_count)
      assert_equal(0, handler.removal_count)
    end

    # #4482 の回帰テスト。TaggingDictionary は 1 イベント＝1 投稿の中で
    # 全ハンドラが共有する（Event#handlers が同一の params を全ハンドラへ渡す）。
    def test_dictionary_is_shared_within_event
      params = {}
      handler = create_handler(params)
      other = create_handler(params)
      params[:tagging_dictionary] = Set['sentinel']

      assert_same(params[:tagging_dictionary], handler.dictionary)
      assert_same(handler.dictionary, other.dictionary)
    end
  end
end
