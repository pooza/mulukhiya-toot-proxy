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

    # 既に値があれば書き換えない SET (#4575)。獲得できたとき true。
    #
    # ⚠ **キャッシュを「温める」読み経路はこちらを使うこと。**素の SET だと、
    # 古い内容を読んだ読み手が、その後に完走した書き手の新しい値を上書きできる。
    # 番組表のように読みがロックの外にある構造では、それが恒久的なロールバックに
    # なる（読みはキャッシュを優先するので、以後ずっと旧データが返る）。
    # ⚠ Naming/PredicateMethod を inline disable する。真偽値を返すが、これは
    # 述語ではなく「獲得できたか」を返す副作用付きコマンド。`setnx?` にすると
    # 副作用の無い問い合わせに見えるので、Redis のコマンド名のまま残す。
    def setnx(key, value) # rubocop:disable Naming/PredicateMethod
      value = '' if value.nil?
      return redis.call('SET', create_key(key), value, 'NX') == 'OK'
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
