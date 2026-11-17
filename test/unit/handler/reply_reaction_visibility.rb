module Mulukhiya
  # 元の投稿の公開範囲で、リアクションを伝える返信の公開範囲を決める（5.46.0 のリリース前レビュー）。
  # ⚠ ハンドラの名前で終わらないファイル名にしてある（`_handler` で終わると `skip_case?` が
  # 設定と DB でハンドラを作ろうとして、手元と CI では飛ばされる）。⚠ DB に繋がない。
  # ⚠ `@handler` は使わない（`TestCase#teardown` が `@handler&.clear` を呼ぶ）。
  class ReplyReactionVisibilityTest < TestCase
    def setup
      @target = ReplyReactionHandler.allocate
      @target.define_singleton_method(:bridge_domains) {['bridge.example.com']}
      @receipt = Struct.new(:domain).new('mastodon.example.com')
      @bridge = Struct.new(:domain).new('bridge.example.com')
    end

    def test_reply_visibility_public
      assert_equal(:unlisted, @target.reply_visibility(status(:public), @receipt))
      assert_equal(:public, @target.reply_visibility(status(:public), @bridge))
    end

    def test_reply_visibility_unlisted
      assert_equal(:unlisted, @target.reply_visibility(status(:unlisted), @receipt))
    end

    def test_reply_visibility_private
      assert_equal(:direct, @target.reply_visibility(status(:private), @receipt))
      assert_equal(:direct, @target.reply_visibility(status(:private), @bridge))
    end

    def test_reply_visibility_direct
      assert_equal(:direct, @target.reply_visibility(status(:direct), @receipt))
    end

    private

    def status(name)
      return Struct.new(:visibility_name).new(controller_class.visibility_name(name))
    end
  end
end
