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

    def self.health
      return {status: 'OK', skipped: true} unless config?
      instance.connection.fetch('SELECT 1 AS ok').first
      return {status: 'OK'}
    rescue Sequel::PoolTimeout => e
      return {error: e.message, status: 'WARN', reason: 'pool_exhausted'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
