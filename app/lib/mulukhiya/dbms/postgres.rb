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
