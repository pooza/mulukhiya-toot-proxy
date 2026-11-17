module Mulukhiya
  # 利用者向けのハンドラ一覧 `GET /handler/list` の中身 (#4195)。
  #
  # ⚠ `Handler.new` は SNS 経由で DB を触るので `allocate` で組む。`to_user_h` が読むのは
  # クラス名・スキーマ・設定だけ。利用者の設定は `disable?(handler)` を持つ偽物で渡す。
  class HandlerUserListTest < TestCase
    FakeAccount = Struct.new(:disabled_names) do
      def disable?(handler)
        return disabled_names.member?(handler.underscore)
      end
    end

    NAMES = ['default_tag', 'invalid_command', 'image_resize'].freeze

    def setup
      # ⚠ 設定に無いキーは `ConfigError` になる。無かったものは false で戻す（`disable?` の読みは同じ）。
      @originals = NAMES.to_h {|name| [name, (config["/handler/#{name}/disable"] rescue false)]}
      NAMES.each {|name| config["/handler/#{name}/disable"] = false}
      @handlers = [DefaultTagHandler, InvalidCommandHandler, ImageResizeHandler].map(&:allocate)
      # ⚠ サブクラスの `disable?` はサーバーの状態（辞書・タグの設定など）を見るので、既定は「動く」に固定する。
      @handlers.each {|handler| handler.define_singleton_method(:disable?) {false}}
    end

    def teardown
      @originals&.each {|name, value| config["/handler/#{name}/disable"] = value}
    end

    def test_fields
      entry = Handler.user_list(FakeAccount.new([]), @handlers).find {|v| v[:name] == 'default_tag'}

      assert_equal([:name, :label, :description, :toggleable, :disabled], entry.keys)
      assert_equal(DefaultTagHandler.allocate.label, entry[:label])
      assert_equal(DefaultTagHandler.allocate.description, entry[:description])
    end

    # `disabled` は利用者の設定を映す。
    def test_disabled_follows_user_config
      list = Handler.user_list(FakeAccount.new(['image_resize']), @handlers)

      assert(list.find {|v| v[:name] == 'image_resize'}[:disabled])
      assert_false(list.find {|v| v[:name] == 'default_tag'}[:disabled])
    end

    # 切り替えられないものも一覧に含め、`toggleable: false` で返す。
    def test_includes_non_toggleable
      entry = Handler.user_list(FakeAccount.new([]), @handlers).find {|v| v[:name] == 'invalid_command'}

      assert_not_nil(entry)
      assert_false(entry[:toggleable])
    end

    # 切り替えられないものは、利用者の設定に無効と書いてあっても動いているので `disabled: false` (#4196)。
    def test_non_toggleable_ignores_user_config
      entry = Handler.user_list(FakeAccount.new(['invalid_command']), @handlers).find {|v| v[:name] == 'invalid_command'}

      assert_false(entry[:disabled])
    end

    # サーバー全体で無効なものは見せない。
    def test_excludes_globally_disabled
      config['/handler/image_resize/disable'] = true
      names = Handler.user_list(FakeAccount.new([]), @handlers).map {|v| v[:name]}

      assert_equal(['default_tag', 'invalid_command'], names)
    end

    # このサーバーでは動かないもの（サブクラスの `disable?` が true）は見せない（5.47.0 のリリース前レビュー）。
    def test_excludes_unavailable
      @handlers.last.define_singleton_method(:disable?) {true}
      names = Handler.user_list(FakeAccount.new([]), @handlers).map {|v| v[:name]}

      assert_equal(['default_tag', 'invalid_command'], names)
    end

    # 利用者が自分で止めたものは、`disable?` が true でも戻せるように見せる。
    def test_includes_disabled_by_user
      @handlers.last.define_singleton_method(:disable?) {true}
      entry = Handler.user_list(FakeAccount.new(['image_resize']), @handlers).find {|v| v[:name] == 'image_resize'}

      assert(entry[:disabled])
    end

    # 判定で例外が出たら見せる側に倒す。
    def test_includes_when_judgement_fails
      @handlers.last.define_singleton_method(:disable?) {raise 'broken'}
      names = Handler.user_list(FakeAccount.new([]), @handlers).map {|v| v[:name]}

      assert_includes(names, 'image_resize')
    end

    # 通知（alert）のハンドラは利用者の投稿で動かないので見せない。
    def test_excludes_alert_handlers
      handlers = @handlers + [SlackAlertHandler.allocate]
      handlers.last.define_singleton_method(:disable?) {false}
      names = Handler.user_list(FakeAccount.new([]), handlers).map {|v| v[:name]}

      assert_not_include(names, 'slack_alert')
    end
  end
end
