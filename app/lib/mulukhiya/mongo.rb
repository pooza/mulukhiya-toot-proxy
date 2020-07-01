require 'mongo'

module Mulukhiya
  class Mongo < Mongo::Client
    include Singleton

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

    def initialize(hosts = [], params = {})
      dsn = Mongo.dsn
      raise Ginseng::DatabaseError, 'Invalid DSN' unless dsn.valid?
      hosts ||= ["#{dsn.host}:#{dsn.port}"]
      params ||= {database: dsn.dbname}
      super
    end
  end
end
