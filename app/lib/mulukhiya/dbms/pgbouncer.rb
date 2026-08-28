require 'pg'

module Mulukhiya
  # pgbouncer の待ち行列を `/health` に載せる (#4618 の P1)。
  #
  # ⚠⚠ **`Postgres.pool` が読むのは `/health` を処理した Puma プロセスの Sequel
  # プール 1 つだけ**で、実際に枯れる資源とは別物。pgbouncer は **Mastodon 本体・
  # モロヘイヤの Puma・Sidekiq が共有**していて、重い SQL を流す
  # `MediaCatalogUpdateWorker` は別プロセス＝別プールなので、worker が pgbouncer を
  # 占有しても Puma 側の `allocated` / `waiting` には直接出ない。
  #
  # ⚠ **#4639（Gate 2 の overlay flip）の rollback 信号。**flip する前に、
  # 信号のほうを信用できる状態にしておく。2026-05-19 の全サーバー投稿不可は
  # ここの枯渇が最有力だった（#4323 / pooza/chubo2#37）。
  #
  # ⚠ **admin コンソールは資格情報を要らない。**chubo-core の pgbouncer cookbook が
  # `auth_type = trust` / `admin_users = pgbouncer` を書くので、アプリの DSN と
  # **同じ host:port** へ `pgbouncer` ユーザーで入れる。秘密を増やさないので config も
  # 増やさない。⚠ trust はローカルホスト前提であり、**同じ箱で動くプロセスなら
  # 誰でも既に持っている経路**。モロヘイヤが新しい権限を得るわけではない。
  class Pgbouncer
    include Package

    ADMIN_USER = 'pgbouncer'.freeze
    ADMIN_DBNAME = 'pgbouncer'.freeze

    # 素の PostgreSQL の既定ポート。ここを向いているなら pgbouncer は挟まっていない
    # （本番 4 台のうち vulcan がこれ＝ Misskey / Linux で cookbook の対象外）。
    #
    # ⚠⚠ **素の Postgres へ `pgbouncer` ユーザーで入りに行かないこと。**認証失敗が
    # `/health` を叩くたびに PostgreSQL のログへ溜まる。ポートで手前に切る。
    DIRECT_PORT = 5432

    # `SHOW POOLS` から読む列。⚠ **`cl_waiting` が本命**——サーバー接続を待って
    # ブロックしているクライアント数で、これが 0 を超えたらプールが要求に足りていない。
    # `maxwait` は待ちの最長秒数で、瞬間値の `cl_waiting` が 0 に戻っていても
    # 直前の詰まりが残る。
    POOL_FIELDS = ['cl_active', 'cl_waiting', 'sv_active', 'sv_idle', 'maxwait'].freeze

    class << self
      # `{pgbouncer: {...}}` を返す。⚠ **観測が取れないこと自体で health を落とさない**
      # （`Postgres.pool` と同じ設計）。status は呼び側で触らない。
      def health
        return {} unless enable?
        return {pgbouncer: probe}
      rescue => e
        # ⚠ **繋がらないこと自体が信号になりうる**（`max_client_conn` 枯渇なら
        # 「no more connections allowed」が返る）。潰さずメッセージを出す。
        # ⚠ ただし status は動かさない。pgbouncer の停止と枯渇を接続失敗からは
        # 区別できず、health を WARN に倒すと再起動のたびに揺れる。
        e.log
        return {pgbouncer: {error: e.message}}
      end

      # ⚠ 既定は `null` ＝ ポートによる自動判定。`true` / `false` で固定できる。
      # config の参照を rescue で握り潰さないこと。既定値は application.yaml が
      # 必ず持つので、引けない状態は設定の破損である
      # (MEMORY feedback_fail-open-guard-footgun)。
      def enable?
        value = config['/postgres/pgbouncer/enable']
        return value if [true, false].include?(value)
        return proxied?
      end

      # DSN が素の PostgreSQL 以外のポートを向いていれば pgbouncer とみなす。
      def proxied?
        port = Postgres.dsn&.port
        return false unless port
        return port.to_i != DIRECT_PORT
      end

      private

      def probe
        connection = connect
        pool = pool_row(connection)
        return {
          database: dsn.dbname,
          # ⚠ 該当プールがまだ作られていないことはある（誰も繋いでいない）。
          # **0 と「不明」は違う**ので、行が無いときは値を載せない。
          **(pool ? POOL_FIELDS.to_h {|k| [k.to_sym, pool[k].to_i]} : {absent: true}),
          **clients(connection),
        }
      ensure
        connection&.close
      end

      def connect
        return PG.connect(
          host: dsn.host,
          port: dsn.port,
          user: ADMIN_USER,
          dbname: ADMIN_DBNAME,
          connect_timeout: config['/postgres/pgbouncer/timeout'],
        )
      end

      # 自分と同じ (database, user) の行。⚠ **Mastodon 本体と同じ行になる**——
      # 同じ DSN で繋いでいるので、これがまさに共有している待ち行列。
      def pool_row(connection)
        return connection.exec('SHOW POOLS').find do |row|
          row['database'] == dsn.dbname && row['user'] == dsn.user
        end
      end

      # 全プール合計のクライアント数と上限。⚠ **2026-08-02 の gomander
      # （FeedUpdateWorker 全滅）と 2026-08-08 の shallu はどちらも
      # `no more connections allowed (max_client_conn)`** で、枯れたのは
      # プールごとの待ちではなく**箱全体のクライアント数**だった。
      def clients(connection)
        used = connection.exec('SHOW LISTS').find {|row| row['list'] == 'used_clients'}
        max = connection.exec('SHOW CONFIG').find {|row| row['key'] == 'max_client_conn'}
        return {
          clients_used: used && used['items'].to_i,
          clients_max: max && max['value'].to_i,
        }.compact
      end

      def dsn
        return Postgres.dsn
      end
    end
  end
end
