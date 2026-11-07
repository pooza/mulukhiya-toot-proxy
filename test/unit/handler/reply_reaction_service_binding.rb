module Mulukhiya
  # API で読む投稿（`Pleroma::Status`）を、リアクションした本人のサービスで読む（PR #4891 の Codex P2）。
  # ⚠ ハンドラの名前で終わらないファイル名にしてある（`_handler` で終わると、`skip_case?` が
  # 設定と DB でハンドラを作ろうとして、手元と CI では飛ばされる）。⚠ DB に繋がない。
  # ⚠ `@handler` は使わない（`TestCase#teardown` が `@handler&.clear` を呼ぶ）。
  class ReplyReactionServiceBindingTest < TestCase
    def setup
      @sns = Object.new
      @status = Pleroma::Status.new('status-id')
      @target = ReplyReactionHandler.allocate
      status = @status
      sns = @sns
      @target.define_singleton_method(:status_class) {{'status-id' => status}}
      @target.define_singleton_method(:status_key) {:id}
      @target.define_singleton_method(:sns) {sns}
    end

    # ⚠ 読み出し（`service`）は既定のサービスを作りに行くので、渡された値そのものを見る。
    def test_target_status
      assert_same(@status, @target.target_status({id: 'status-id'}))
      assert_same(@sns, @status.instance_variable_get(:@service))
    end

    def test_target_status_missing
      assert_nil(@target.target_status({id: 'no-such-status'}))
    end

    # DB から読む投稿は `service=` を持たないので、触らない。
    def test_target_status_without_writer
      status = Object.new
      @target.define_singleton_method(:status_class) {{'status-id' => status}}

      assert_same(status, @target.target_status({id: 'status-id'}))
    end
  end
end
