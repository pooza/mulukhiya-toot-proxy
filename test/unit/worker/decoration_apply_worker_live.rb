module Mulukhiya
  # 実況のデコの記録（`/decoration/live`）が書けなかったら、デコを付けない（PR #4937 の Codex の P2）。
  # `UserConfig#update` は失敗を握りつぶして nil を返すので、それを使うと「付いているのに記録が無い」になり、
  # 番組の終わり・毎日の一括の戻し・手で戻す口のどれもが外さない。Misskey へは行かない。
  class DecorationApplyWorkerLiveTest < TestCase
    def disable?
      return true unless Environment.misskey_type?
      return super
    end

    def setup
      return if disable?
      @worker = Worker.create(:decoration_apply)
      @updates = []
      updates = @updates
      service = Class.new do
        attr_accessor :token

        define_method(:fetch_account_detail) {{'avatarDecorations' => []}}
        define_method(:fetch_avatar_decorations) {[{'id' => 'deco1', 'name' => 'デコ'}]}
        define_method(:update_account) {|params| updates.push(params)}
      end
      @worker.define_singleton_method(:sns_class) {service}
      @worker.define_singleton_method(:log) {|_message| nil}
    end

    def test_apply_decoration_without_live_record
      account = stub_account {raise Ginseng::Redis::Error, 'Connection refused'}
      @worker.apply_decoration(account, program: '番組', restore_at: Time.now.iso8601)

      assert_empty(@updates)
    end

    def test_apply_decoration
      account = stub_account {|values| values}
      @worker.apply_decoration(account, program: '番組', restore_at: Time.now.iso8601)

      assert_equal([{avatarDecorations: [{'id' => 'deco1'}]}], @updates)
    end

    private

    def stub_account(&)
      config = Object.new
      config.define_singleton_method(:[]) {|key| key == '/decoration/id' ? 'deco1' : nil}
      config.define_singleton_method(:token) {'token'}
      config.define_singleton_method(:update!, &)
      # `update` は本物と同じく失敗を握りつぶす。
      config.define_singleton_method(:update) {|values| update!(values) rescue nil}
      account = Object.new
      account.define_singleton_method(:user_config) {config}
      account.define_singleton_method(:acct) {'@pooza@example.com'}
      return account
    end
  end
end
