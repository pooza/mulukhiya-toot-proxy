module Mulukhiya
  class Redis < Ginseng::Redis::Service
    def initialize(params = {})
      unless params[:url]
        dsn = Redis.dsn
        dsn.db ||= 1
        raise Error, "Invalid DSN '#{dsn}'" unless dsn.absolute?
        raise Error, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
        params[:url] = dsn.to_s
      end
      super
    end

    def self.dsn
      return Ginseng::Redis::DSN.parse(Config.instance['/user_config/redis/dsn'])
    end

    def self.health
      redis = Redis.new
      redis.get('1')
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
