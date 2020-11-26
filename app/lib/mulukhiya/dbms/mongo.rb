module Mulukhiya
  class Mongo
    include Singleton
    attr_reader :db

    def self.dsn
      return MongoDSN.parse(Config.instance['/mongo/dsn'])
    rescue Ginseng::ConfigError
      return nil
    end

    def self.connect
      return instance
    end

    def self.config?
      return dsn.present?
    end

    def self.health
      Environment.account_class.get(token: Config.instance['/agent/info/token'])
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end

    private

    def initialize
      dsn = Mongo.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless dsn.valid?
      @db = ::Mongo::Client.new(["#{dsn.host}:#{dsn.port}"], {
        database: dsn.dbname,
        user: dsn.user,
        password: dsn.password,
        logger: Logger.new,
      })
    end
  end
end
