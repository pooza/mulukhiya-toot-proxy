require 'mongo'

module Mulukhiya
  class Mongo
    include Singleton
    include Package
    attr_reader :db

    def self.dsn
      return MongoDSN.parse(config['/mongo/dsn']) rescue nil
    end

    def self.connect
      return instance if config?
    end

    def self.config?
      return dsn.present?
    end

    def self.health
      Environment.account_class.get(token: Environment.account_class.info_token)
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end

    def self.create_logger
      if Environment.development? || Evnironment.test? || config['/mongo/query_log']
        return Logger.new
      else
        return ::Logger.new('/dev/null')
      end
    end

    private

    def initialize
      dsn = Mongo.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless dsn.valid?
      @db = ::Mongo::Client.new(["#{dsn.host}:#{dsn.port}"], {
        database: dsn.dbname,
        user: dsn.user,
        password: dsn.password,
        logger: Mongo.create_logger,
      })
    end
  end
end
