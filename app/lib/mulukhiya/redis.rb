module Mulukhiya
  class Redis < Ginseng::Redis::Service
    include Package

    def initialize(params = {})
      unless params[:url]
        dsn = Redis.dsn
        dsn.db ||= 1
        raise Ginseng::Redis::Error, "Invalid DSN '#{dsn}'" unless dsn.absolute?
        raise Ginseng::Redis::Error, "Invalid scheme '#{dsn.scheme}'" unless dsn.scheme == 'redis'
        params[:url] = dsn.to_s
      end
      super
    end

    def clear
      bar = ProgressBar.create(total: all_keys.count) if Environment.rake?
      all_keys.each do |key|
        unlink(key)
      ensure
        bar&.increment
      end
      bar&.finish
      @logger.info(class: self.class.to_s, prefix: prefix, message: 'clear')
    end

    def self.dsn
      return Ginseng::Redis::DSN.parse(config['/user_config/redis/dsn'])
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
