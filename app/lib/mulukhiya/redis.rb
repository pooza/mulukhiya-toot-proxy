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

    def underscore
      return self.class.to_s.split('::').last.sub(/Storage$/, '').underscore
    end

    def log(message)
      logger.info({storage: underscore}.merge(message))
    end

    def clear
      bar = ProgressBar.create(total: all_keys.count)
      all_keys.each do |key|
        unlink(key)
      ensure
        bar&.increment
      end
      bar&.finish
      log(method: __method__, prefix:)
    end

    def self.dsn
      return Ginseng::Redis::DSN.parse(config['/user_config/redis/dsn'])
    end

    def self.health
      new.get('1')
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end
  end
end
