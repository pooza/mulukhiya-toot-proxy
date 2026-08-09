module Mulukhiya
  class ComposeTemplateContainerTest < TestCase
    def disable?
      return true unless account
      return super
    end

    def setup
      return if disable?
      @container = ComposeTemplateContainer.new(account)
      account.user_config.update(compose: nil)
    end

    def teardown
      return if disable?
      account.user_config.update(compose: nil)
    end

    def test_empty
      assert_equal([], @container.all)
      assert_nil(@container.find('nonexistent'))
    end

    def test_create
      template = @container.create(name: '実況開始', body: 'はじまるよ')

      assert_predicate(template['id'], :present?)
      assert_equal('実況開始', template['name'])
      assert_equal('はじまるよ', template['body'])
      assert_nil(template['cw'])
      assert_equal(1, @container.all.size)
      assert_equal(template, @container.find(template['id']))
    end

    def test_create_assigns_unique_id
      a = @container.create(name: 'a', body: 'a')
      b = @container.create(name: 'b', body: 'b')

      assert_not_equal(a['id'], b['id'])
      assert_equal(2, @container.all.size)
    end

    def test_create_with_cw
      template = @container.create(name: 'CW あり', body: '本文', cw: '注意書き')

      assert_equal('注意書き', template['cw'])
      assert_equal('注意書き', @container.find(template['id'])['cw'])
    end

    def test_create_blank_cw_becomes_nil
      template = @container.create(name: '空 CW', body: '本文', cw: '')

      assert_nil(template['cw'])
    end

    def test_create_empty_body_is_allowed
      template = @container.create(name: '空本文', body: '')

      assert_equal('', template['body'])
      assert_equal('', @container.find(template['id'])['body'])
    end

    def test_update
      template = @container.create(name: '旧', body: '旧本文')
      updated = @container.update(template['id'], name: '新', body: '新本文', cw: 'CW')

      assert_equal(template['id'], updated['id'])
      assert_equal('新', updated['name'])
      assert_equal('新本文', updated['body'])
      assert_equal('CW', updated['cw'])
      assert_equal(1, @container.all.size)
      assert_equal('新本文', @container.find(template['id'])['body'])
    end

    def test_update_not_found
      assert_raise(Ginseng::NotFoundError) do
        @container.update('nonexistent', name: 'x', body: 'y')
      end
    end

    def test_delete
      template = @container.create(name: '消す', body: '本文')

      assert_equal(template, @container.delete(template['id']))
      assert_equal([], @container.all)
      assert_nil(@container.find(template['id']))
    end

    def test_delete_not_found
      assert_raise(Ginseng::NotFoundError) do
        @container.delete('nonexistent')
      end
    end

    # 別リクエストがロック保持中は 409 で弾き、lost update を防ぐ（#4457/#4460）。
    def test_write_conflicts_while_locked
      lock = ComposeTemplateLockStorage.new
      token = lock.send(:acquire, account.id)
      begin
        assert_raise(Ginseng::ConflictError) do
          @container.create(name: 'x', body: 'y')
        end
      ensure
        lock.send(:release, account.id, token)
      end
      # 解放後は通常どおり作成できる。
      assert_predicate(@container.create(name: 'x', body: 'y')['id'], :present?)
    end

    # ロック取得前にメモ化された user_config を掴んでいても、ロック内で読み直す
    # ため他リクエストの書き込みを踏み潰さない (#4461)。
    def test_write_reloads_user_config_inside_lock
      # 古いスナップショットを掴ませる（@account.user_config はメモ化される）。
      @container.all
      other = ComposeTemplateContainer.new(account)
      other.create(name: '別リクエスト', body: 'x')
      @container.create(name: 'こちら', body: 'y')

      # ⚠ 読み直しは**新しい account** から行う。`Account#user_config` は account
      # オブジェクト側でメモ化されるので、`TestCase#account`（`@account ||=`）が返す
      # 同じインスタンスを渡すと 1 行目の `@container.all` で掴んだ空スナップショットを
      # そのまま読んでしまい、書き込みが成功していても 0 件に見える。本番は 1 リクエスト
      # 1 account なのでこれは検証側の作り込みの問題で、product の退行ではない (#4552)。
      names = ComposeTemplateContainer.new(account_class.test_account).all.map {|v| v['name']}

      assert_equal(2, names.size)
      assert_includes(names, '別リクエスト')
      assert_includes(names, 'こちら')
    end

    # 保存失敗は UserConfig 側で alert させず GatewayError 一本に畳む（二重 alert
    # を避ける）。呼び出し側から見た挙動＝5xx は従来どおり (#4461)。
    def test_persist_failure_raises_gateway_error
      container = ComposeTemplateContainer.new(account)
      stub = UserConfig.new(account)
      stub.define_singleton_method(:update!) {|*| raise 'boom'}
      # alert する側 (update) を踏まないこと自体を検証する。
      stub.define_singleton_method(:update) {|*| raise '二重 alert になる update を呼んでいる'}
      container.instance_variable_set(:@user_config, stub)

      assert_raise(Ginseng::GatewayError) do
        container.send(:persist, [])
      end
    end

    def test_max_count
      templates = Array.new(ComposeTemplateContainer::MAX_COUNT) do |i|
        {'id' => SecureRandom.uuid, 'name' => "t#{i}", 'body' => 'x'}
      end
      account.user_config.update(compose: {templates:})

      assert_equal(ComposeTemplateContainer::MAX_COUNT, @container.all.size)
      assert_raise(Ginseng::ConflictError) do
        @container.create(name: 'over', body: 'x')
      end
    end
  end
end
