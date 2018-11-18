require 'pg'
require 'erb'
require 'singleton'

module MulukhiyaTootProxy
  class Postgres
    include Singleton

    def initialize
      @config = Config.instance
      dsn = Postgres.dsn
      dsn.dbname ||= 'mastodon'
      raise DatabaseError, "Invalid DSN '#{dsn}'" unless dsn.absolute?
      raise DatabaseError, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'postgres'
      @db = PG.connect(Postgres.dsn.to_h)
    rescue PG::Error => e
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
    rescue PG::Error => e
      raise DatabaseError, e.message
    end

    def self.dsn
      return PostgresDSN.parse(Config.instance['local']['postgres']['dsn'])
    rescue
      return PostgresDSN.parse('postgres://postgres@localhost:5432/mastodon')
    end
  end
end
