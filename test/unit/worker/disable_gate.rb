module Mulukhiya
  # disable? を override している worker が、perform でも短絡することを機械的に検査する。
  #
  # sidekiq-scheduler は Worker.perform_async を介さず Sidekiq::Client.push を直叩き
  # するため、schedule 経由の起動は perform_async 側の disable? gate を通らない。
  # 短絡を書き忘れると、機能を無効にしたサーバーでも本体が 1〜10 分おきに走る
  # (#4343 / #4506)。個別の worker テストに任せると新しい worker で必ず忘れるので、
  # 全 worker を列挙して一括で見る。
  class WorkerDisableGateTest < TestCase
    # ⚠ StandardError を継承させない。worker 本体の `rescue => e` に飲まれると、
    # 「走ったのに気づけない」という #4536 の検出漏れがそのまま再発する。
    class GateTripped < ScriptError; end

    # 本体の入口に仕掛ける seam。走れば必ずどれかを通る。
    #
    # log だけに頼ると DecorationApplyWorker を取りこぼす (#4536)。あれは
    # initialize_params({}) が params 空で即 return し、account_class[nil] が nil を
    # 返し、apply_decoration(nil) の内部 rescue が例外を飲むため、ゲートを外しても
    # 外から見て「何も起きていない」ように見える。
    TRIPWIRES = [:initialize_params, :account_class, :sns_class, :worker_config].freeze

    # ⚠ subclasses は直接の子しか返さない。PiefedClippingWorker のように
    # ClippingWorker を挟む worker を取りこぼすので descendants を使う。
    def gated_workers
      load_all_workers
      return Worker.descendants.select do |klass|
        klass.instance_method(:disable?).owner == klass
      end
    end

    # ⚠ descendants は「その時点で読み込まれたクラス」しか返さない。zeitwerk の
    # 遅延ロード下でこのケースだけ単独実行すると 1 本しか列挙されず、検査が
    # 丸ごと空振りしていた (rake test では他のテストが読んでいたので気づけない)。
    # 列挙の入口で必ず全 worker を読む。
    def load_all_workers
      Dir.glob(File.join(Environment.dir, 'app/lib/mulukhiya/worker/*.rb')).each do |path|
        "Mulukhiya::#{File.basename(path, '.rb').camelize}".constantize
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

    # 動的テストは「本体が走ったことを外から観測できる」ことに依存する。観測手段を
    # 増やしても、本体が何も触らず何も投げない worker が現れれば同じ穴が空く。
    # ゲートの有無だけはソースで機械的に見る (#4536)。
    def test_gate_is_the_first_statement_of_perform
      offenders = gated_workers.reject {|klass| gate_first?(klass)}

      assert_empty(
        offenders.map(&:to_s).sort,
        'perform の最初の実行文が `return if disable?` になっていない worker がある (#4506)',
      )
    end

    # 検査器そのものが空振りしていないことの担保。ゲートを持たない perform を
    # 「持っている」と誤判定しないこと。
    def test_gate_detector_rejects_ungated_perform
      assert_false(gate_first?(UngatedProbeWorker), 'ゲート無しを検出できていない')
      assert_true(gate_first?(ProgramUpdateWorker), 'ゲート有りを取りこぼしている')
    end

    # tripwire が実際に発火すること。ここが死ぬと
    # test_disabled_workers_do_not_run_perform が「全員合格」で緑になる。
    def test_tripwire_detects_body_execution
      assert_false(short_circuits?(UngatedProbeWorker), 'ゲート無しの本体実行を検出できていない')
    end

    # ゲートを持たず、log も呼ばず、自分の例外も飲む worker。#4536 で
    # 取りこぼしていた DecorationApplyWorker の形をそのまま写した検査用ダブル。
    #
    # ⚠ disable? を override しないこと。gated_workers に混ざって本番の worker と
    # 同じ検査対象になってしまう。
    class UngatedProbeWorker < Worker
      def perform(params = {})
        initialize_params(params)
        nil
      rescue StandardError
        nil
      end
    end

    private

    def short_circuits?(klass)
      worker = klass.new
      worker.define_singleton_method(:disable?) {true}
      called = false
      worker.define_singleton_method(:log) {|_message| called = true}
      TRIPWIRES.each do |name|
        next unless worker.respond_to?(name, true)
        worker.define_singleton_method(name) {|*, **| raise GateTripped, name.to_s}
      end
      worker.perform({})
      return !called
    rescue GateTripped, StandardError
      # GateTripped = 本体が入口の seam を踏んだ、StandardError = 本体が走って落ちた。
      # どちらも短絡していない。
      return false
    end

    # perform の最初の実行文が `return if disable?` かどうか。コメントと空行は読み飛ばす。
    def gate_first?(klass)
      statement = first_statement(klass.instance_method(:perform))
      return statement == 'return if disable?'
    end

    def first_statement(method)
      file, line = method.source_location
      return nil unless file && File.exist?(file)
      # source_location は `def perform` の行を指すので、その次の行から読む。
      File.readlines(file)[line..].each do |row|
        row = row.strip
        next if row.empty? || row.start_with?('#')
        return row
      end
      return nil
    end
  end
end
