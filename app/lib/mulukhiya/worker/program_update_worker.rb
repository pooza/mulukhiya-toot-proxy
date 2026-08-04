module Mulukhiya
  class ProgramUpdateWorker < Worker
    sidekiq_options retry: false

    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def perform(params = {})
      # every 1m。実況非対応サーバーでも Program#update が番組表の取得と保存を
      # 毎分行ってしまう (#4506)。
      return if disable?
      Program.instance.update
      log(programs: Program.instance.count)
    end
  end
end
