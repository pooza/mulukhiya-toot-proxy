module Mulukhiya
  class NodeInfo
    include Singleton
    include Package
    include SNSMethods

    def update
      service = sns_class.new
      raw = ginseng_class(service.class).instance_method(:nodeinfo).bind_call(service)
      # ⚠ 上流の一時障害で gem は空を返す。書くと、次の成功までノード名が消える。
      return if raw.blank?
      if service.respond_to?(:theme_color)
        raw['metadata'] ||= {}
        raw['metadata']['themeColor'] = service.theme_color
      end
      result = raw.merge('mulukhiya' => config.about)
      return redis['nodeinfo'] = result.to_json
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

    private

    # nodeinfo を実際に取りにいく gem 側のクラス。
    #
    # ⚠⚠ **1 つ上のクラスとは限らない (#4860)。**`PleromaService` の 1 つ上はモロヘイヤの
    # `MastodonService` で、その `nodeinfo` は**このキャッシュを返す**。以前は 1 つ上を
    # 呼んでいたので、Pleroma 系では更新が自分のキャッシュを読み直すだけになり
    # （サーバー名を変えても古い名前が残る）、最初の 1 回も `metadata` を symbol の鍵で
    # 上書きして `nodeName` を落としていた（タグのフィードのチャンネル名が空になる）。
    def ginseng_class(service_class)
      return service_class.ancestors.find do |v|
        v.is_a?(Class) && v.name.to_s.start_with?('Ginseng::')
      end
    end
  end
end
