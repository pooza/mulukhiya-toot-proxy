module Mulukhiya
  class Postgres < Ginseng::Postgres::Database
    include Package

    def execute(name, params = {})
      return super(name, params).map(&:with_indifferent_access)
    end

    def self.connect
      return instance
    end

    def self.config?
      return Postgres.dsn.present?
    end

    def self.dsn
      return Ginseng::Postgres::DSN.parse(Config.instance['/postgres/dsn'])
    rescue Ginseng::ConfigError
      return nil
    end

    def self.health
      Environment.account_class.get(token: Config.instance['/test/token'])
      return {status: 'OK'}
    rescue
      return {status: 'NG'}
    end
  end
end
