module Mulukhiya
  class FeedUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.feed?
      return true unless CustomFeed.all.present?
      return super
    end

    def perform(params = {})
      # every 5m。CustomFeed はサブプロセス (bin/*.rb) を起動するため、フィードを
      # 持たないサーバーでも 5 分おきにプロセス生成と DB 接続を試みる (#4506)。
      return if disable?
      CustomFeed.all(&:update)
      log(feeds: CustomFeed.count)
    end
  end
end
