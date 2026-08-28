require 'ginseng/postgres'

module Mulukhiya
  class Postgres < Ginseng::Postgres::Database
    include Package

    def loggable?
      return Environment.test? || Environment.development? || config['/postgres/query_log']
    end

    def self.connect
      return instance if config?
    end

    # singleton インスタンスが生成済みか。reconnect の張り直し判定に使う。
    def self.connected?
      return !instance_variable_get(:@singleton__instance__).nil?
    end

    # config 変更後に DB 接続を張り直す。Postgres は Singleton のため、既存
    # インスタンスは生成時の DSN を保持し続け connect では更新されない。既存接続を
    # 切ってから singleton をリセットし、現在の config['/postgres/dsn'] で繋ぎ直す。
    def self.reconnect
      instance.connection.disconnect if connected?
      Singleton.__init__(self)
      return connect
    end

    def self.exec(name, params = {})
      return instance.exec(name, params)
    end

    def self.first(name, params = {})
      return instance.exec(name, params)&.first
    end

    def self.config?
      return dsn.present?
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(config['/postgres/dsn']) rescue nil
    end

    # ⚠ **`pool` はこのプロセスの Sequel プールしか見ていない (#4618 の P1)。**
    # 実際に枯れるのは Mastodon 本体・Sidekiq と共有する pgbouncer のほうなので、
    # `Pgbouncer.health` を併せて返す。⚠ **どちらか片方では判断できない。**
    #
    # ⚠⚠ **プールの観測は `SELECT 1` より先に取る (#4618)。**
    # `SELECT 1` 自身がプールから接続を借りるので、詰まっているときは
    # **health のリクエストが待ち行列に並ぶ**。並び終えてから読むと
    # **自分の前の待ちが捌けた後の値**になり、有限のスパイクを丸ごと取りこぼす。
    # 「詰まりに近づいている」を見るための指標なのに、**近づいている瞬間だけ見えない**
    # という逆立ちが起きていた。
    def self.health
      return {status: 'OK', skipped: true} unless config?

      snapshot = pool
      instance.connection.fetch('SELECT 1 AS ok').first
      return {status: 'OK'}.merge(snapshot).merge(Pgbouncer.health)
    rescue Sequel::PoolTimeout => e
      return {error: e.message, status: 'WARN', reason: 'pool_exhausted'}
          .merge(snapshot || pool).merge(Pgbouncer.health)
    rescue => e
      # ⚠ NG のときこそ pgbouncer の生死が要る。「Postgres NG だが pgbouncer は
      # 答える」と「両方死んでいる」は切り分けが真逆になる。
      return {error: e.message, status: 'NG'}.merge(Pgbouncer.health)
    end

    # 接続プールの使用状況 (#4351 Gate 2)。
    #
    # ⚠ **枯渇してからでは遅い。**従来の health は `Sequel::PoolTimeout` を掴んだ
    # ときだけ `pool_exhausted` を出す＝**もう詰まっている**状態しか見えず、
    # 「詰まりに近づいている」を観測できなかった。2026-05-19 の全サーバー投稿不可は
    # 重い media_catalog SQL による接続プール枯渇が最有力で（#4323 / pooza/chubo2#37）、
    # media_catalog を再有効化する前にここが見えている必要がある。
    #
    # ⚠ **`waiting` が本命の指標。**Sequel の TimedQueueConnectionPool は
    # 「使用中の本数」を持たないが、`num_waiting`（接続を待って**ブロックしている
    # スレッド数**）は持つ。これが 0 を超えたら、プールが要求に足りていない。
    # `allocated` が `max` に張り付いているだけなら正常（作った接続を使い回す設計）。
    def self.pool
      pool = instance.connection.pool
      return {pool: {
        max: pool.max_size,
        allocated: pool.size,
        waiting: pool.respond_to?(:num_waiting) ? pool.num_waiting : nil,
      }.compact}
    rescue => e
      # 観測が取れないこと自体で health を落とさない。
      e.log
      return {}
    end
  end
end
