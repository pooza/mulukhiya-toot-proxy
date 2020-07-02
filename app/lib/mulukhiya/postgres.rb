module Mulukhiya
  class Postgres < Ginseng::Postgres::Database
    include Package

    def initialize
      @config = config_class.instance
      dsn = database_class.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless dsn&.valid?
      @connection = Sequel.connect(dsn.to_s)
    rescue => e
      raise Ginseng::DatabaseError, e.message, e.backtrace
    end

    alias exec execute

    def self.connect
      return instance
    end

    def self.config?
      return dsn.present?
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(Config.instance['/postgres/dsn'])
    rescue Ginseng::ConfigError
      return nil
    end

    def self.health
      Environment.account_class.get(token: Config.instance['/agent/info/token'])
      return {
        version: instance.connection.server_version,
        status: 'OK',
      }
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
