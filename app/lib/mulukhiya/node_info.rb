module Mulukhiya
  class NodeInfo
    include Singleton
    include Package
    include SNSMethods

    def update
      service = sns_class.new
      ginseng_class = service.class.superclass
      raw = ginseng_class.instance_method(:nodeinfo).bind_call(service)
      if service.respond_to?(:theme_color)
        raw['metadata'] ||= {}
        raw['metadata']['themeColor'] = service.theme_color
      end
      redis['nodeinfo'] = raw.to_json
      result = raw.merge('mulukhiya' => config.about)
      redis['nodeinfo'] = result.to_json
    rescue => e
      e.log
    end

    def data
      return JSON.parse(redis['nodeinfo'] || '{}')
    end

    def cached?
      return redis['nodeinfo'].present?
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end
  end
end
