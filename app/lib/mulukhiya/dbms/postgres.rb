require 'ginseng/postgres'

module Mulukhiya
  class Postgres < Ginseng::Postgres::Database
    include Package

    def loggable?
      return Environment.test? || Environment.deveopment? || config['/postgres/query_log']
    end

    def self.connect
      return instance if config?
    end

    def self.config?
      return dsn.present?
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(config['/postgres/dsn']) rescue nil
    end

    def self.health
      Environment.account_class.get(token: Environment.account_class.info_token)
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
