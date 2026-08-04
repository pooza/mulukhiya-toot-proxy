module Mulukhiya
  # disable? を override している worker が、perform でも短絡することを機械的に検査する。
  #
  # sidekiq-scheduler は Worker.perform_async を介さず Sidekiq::Client.push を直叩き
  # するため、schedule 経由の起動は perform_async 側の disable? gate を通らない。
  # 短絡を書き忘れると、機能を無効にしたサーバーでも本体が 1〜10 分おきに走る
  # (#4343 / #4506)。個別の worker テストに任せると新しい worker で必ず忘れるので、
  # 全 worker を列挙して一括で見る。
  class WorkerDisableGateTest < TestCase
    # perform を呼んだかどうかの判定に log を使う。対象 worker はいずれも perform 本体で
    # log を呼ぶので、短絡していれば log は呼ばれない。本体が例外を投げた場合も
    # （短絡していない証拠なので）テストは落ちる。
    # ⚠ subclasses は直接の子しか返さない。PiefedClippingWorker のように
    # ClippingWorker を挟む worker を取りこぼすので descendants を使う。
    def gated_workers
      return Worker.descendants.select do |klass|
        klass.instance_method(:disable?).owner == klass
      end
    end

    def test_gated_workers_detected
      # 列挙そのものが壊れると検査が空振りするので、下限を押さえておく。
      assert_operator(gated_workers.size, :>=, 11, 'disable? を持つ worker が検出できていない')
      assert_include(gated_workers, PiefedClippingWorker, '孫クラスを取りこぼしている')
    end

    def test_disabled_workers_do_not_run_perform
      offenders = gated_workers.reject {|klass| short_circuits?(klass)}

      assert_empty(
        offenders.map(&:to_s).sort,
        'disable? が true でも perform 本体が走る worker がある。' \
          'perform 冒頭に `return if disable?` を書くこと (#4506)',
      )
    end

    private

    def short_circuits?(klass)
      worker = klass.new
      worker.define_singleton_method(:disable?) {true}
      called = false
      worker.define_singleton_method(:log) {|_message| called = true}
      worker.perform({})
      return !called
    rescue StandardError
      # 本体が走って落ちた＝短絡していない
      return false
    end
  end
end
