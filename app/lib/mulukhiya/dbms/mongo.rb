require 'mongo'

module Mulukhiya
  class Mongo
    include Singleton
    include Package

    def db
      @db ||= ::Mongo::Client.new(["#{@dsn.host}:#{@dsn.port}"], {
        database: @dsn.dbname,
        user: @dsn.user,
        password: @dsn.password,
        logger: logger,
      })
      return @db
    end

    def loggable?
      return Environment.test? || Environment.development? || config['/mongo/query_log']
    end

    def logger
      @logger ||= Logger.new if loggable?
      @logger ||= ::Logger.new('/dev/null')
      return @logger
    end

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

    private

    def initialize
      @dsn = Mongo.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless @dsn.valid?
    end
  end
end
