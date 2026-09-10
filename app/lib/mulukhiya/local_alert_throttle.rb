module Mulukhiya
  # プロセス内だけで効く alert の抑止（5.37.0 リリース前レビューの赤）。
  #
  # ⚠⚠ **Redis に印を書けないときの受け皿。**`report_error` のデッドマンは
  # 平常時は Redis の `SET NX EX` でクラスタ全体に 1 回だけ鳴らす。だが Redis が
  # 書き込みを拒む状態（ディスク満杯の MISCONF・OOM・READONLY）では印が書けない。
  # そこで **log へ倒すと、全ルートのサーバー側失敗が 1 回も鳴らなくなる**
  # （当初の実装がそうだった）。**鳴らす側へ倒すと、全断中に毎リクエスト鳴る。**
  # どちらも避けるために、**プロセスごとに窓 1 回**まで鳴らす。
  #
  # ⚠ **I/O を持たない。**障害の最中に呼ばれる前提なので、ここでさらに外部へ
  # 依存すると同じ穴に落ちる。単調時計で期限を持つ（壁時計は NTP / VM の補正で飛ぶ）。
  # ⚠ puma のワーカー数ぶん鳴りうるが、**上限は「ワーカー数 × 窓 1 回」で有界**。
  module LocalAlertThrottle
    EXPIRES = Concurrent::Map.new

    # 窓のあいだ一度だけ true を返す。⚠ `compute` は鍵ごとに原子的なので、
    # 同じプロセスの複数スレッドが同時に来ても 1 本だけが獲得する。
    def self.acquire(key, ttl)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      acquired = false
      EXPIRES.compute(key) do |expires_at|
        if expires_at.nil? || expires_at <= now
          acquired = true
          now + ttl
        else
          expires_at
        end
      end
      return acquired
    end

    # テストで「既知の状態から始める」ための入口。
    def self.clear(prefix = nil)
      return EXPIRES.clear unless prefix
      EXPIRES.each_key {|key| EXPIRES.delete(key) if key.to_s.start_with?(prefix)}
    end
  end
end
