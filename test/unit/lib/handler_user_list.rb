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

    # サーバー全体で無効なものは見せない。
    def test_excludes_globally_disabled
      config['/handler/image_resize/disable'] = true
      names = Handler.user_list(FakeAccount.new([]), @handlers).map {|v| v[:name]}

      assert_equal(['default_tag', 'invalid_command'], names)
    end
  end
end
