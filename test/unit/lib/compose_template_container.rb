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

      assert(template['id'].present?)
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
      assert(@container.create(name: 'x', body: 'y')['id'].present?)
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
