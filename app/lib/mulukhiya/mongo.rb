require 'mongo'

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

    private

    def initialize
      dsn = Mongo.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless dsn.valid?
      @db = ::Mongo::Client.new(["#{dsn.host}:#{dsn.port}"], {
        database: dsn.dbname,
        logger: Logger.new,
      })
    end
  end
end
