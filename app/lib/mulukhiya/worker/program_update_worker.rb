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
    rescue Ginseng::ConflictError => e
      # 書き込みロック (#4534) の競合。every 1m なので取りこぼしても次の周回で
      # 追いつく。⚠ alert には上げない。設定・運用の誤りではなく、直列化が
      # 意図どおり働いた結果なので、上げると毎分の Sentry ノイズになる
      # （#4542 と同型の「クライアント起因なのに alert」）。
      log(skipped: 'locked', message: e.message)
    end
  end
end
