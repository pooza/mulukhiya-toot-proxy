require 'pg'
require 'erb'
require 'singleton'

module MulukhiyaTootProxy
  class Postgres
    include Singleton

    def initialize
      @config = Config.instance
      begin
        @db = PG.connect({
          host: @config['local']['postgresql']['host'],
          user: @config['local']['postgresql']['user'],
          password: @config['local']['postgresql']['password'],
          dbname: @config['local']['postgresql']['dbname'],
          port: @config['local']['postgresql']['port'],
        })
      rescue
        @db = PG.connect({
          host: 'localhost',
          user: 'postgres',
          password: nil,
          dbname: 'mastodon',
          port: 5432,
        })
      end
    rescue => e
      raise DatabaseError, e.message
    end

    def escape_string(value)
      return @db.escape_string(value)
    end

    def create_sql(name, params = {})
      params.each do |k, v|
        params[k] = escape_string(v) if v.is_a?(String)
      end
      return ERB.new(@config['query'][name]).result(binding).gsub(/\s+/, ' ')
    end

    def execute(name, params = {})
      return @db.exec(create_sql(name, params)).to_a
    rescue => e
      raise DatabaseError, e.message
    end
  end
end
