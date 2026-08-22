module Mulukhiya
  # 番組表の書き込み経路が ProgramLockStorage を**通っている**ことの検証 (#4534)。
  #
  # ⚠ ProgramTest には置かない。あちらの disable? は livecure?（= var/program.yaml
  # が在るか /program/urls が設定されているか）で丸ごと倒れるので、番組表を持たない
  # 環境ではケースごと omit され一度も走らない。ロックが黙って無効化される事故を
  # 検出するためのテストが、その環境で走らないのでは意味がない
  # （#4549 で absolute_uri をクラスメソッドへ出したのと同じ理由）。
  #
  # ⚠ ここでは書き込みを 1 つも成功させない。全ケースがロック獲得の時点で
  # ConflictError になるため、var/program.yaml も Redis のキャッシュも触らずに済む。
  # 書き込みが通ってしまう＝ロックが素通りしている、なのでその時点で赤になる。
  class ProgramWriteLockTest < TestCase
    LOCKED_MESSAGE = '別の更新が進行中です。少し待って再試行してください。'.freeze

    def disable?
      return true unless Redis.health[:status] == 'OK'
      return super
    end

    def setup
      return if disable?
      @program = Program.instance
      # auto_update が有効だと編集 4 メソッドはロックに到達する前に 409 を返す。
      # ⚠ 同じ ConflictError なので、倒しておかないと**ロックが無くても緑になる**。
      @original_auto_update = config['/program/auto_update']
      config['/program/auto_update'] = false
      @storage = ProgramLockStorage.new
      @token = @storage.send(:acquire)
    end

    def teardown
      return if disable?
      @storage.send(:release, @token) if @token
      config['/program/auto_update'] = @original_auto_update
    end

    def test_add_entry_blocked
      return if disable?

      assert_locked {@program.add_entry('test_lock_add', 'series' => 'A')}
    end

    def test_update_entry_blocked
      return if disable?

      assert_locked {@program.update_entry('test_lock_update', 'episode' => 9)}
    end

    def test_delete_entry_blocked
      return if disable?

      assert_locked {@program.delete_entry('test_lock_delete')}
    end

    def test_increment_episode_blocked
      return if disable?

      assert_locked {@program.increment_episode('test_lock_increment')}
    end

    # 日付 ＋ も書き込みなので同じロックの内側で行う (#4585)。
    def test_advance_next_on_blocked
      return if disable?

      assert_locked {@program.advance_next_on('test_lock_advance')}
    end

    # auto_update の pull（ProgramUpdateWorker）とエディタの編集は同じ YAML /
    # Redis を触るので、save も同じロックで直列化する。別々にすると交差する。
    def test_save_blocked
      return if disable?

      assert_locked {@program.save({})}
    end

    private

    # ⚠ 例外クラスだけでなくメッセージまで見る。auto_update の 409 も
    # ConflictError なので、クラスだけだと**別の理由で緑になった**のを見逃す。
    def assert_locked(&)
      assert(@token, 'ロックを獲得できていない（Redis 不通か fail-open）')
      error = assert_raise(Ginseng::ConflictError, &)

      assert_equal(LOCKED_MESSAGE, error.message)
      assert_equal(409, error.status)
    end
  end
end
