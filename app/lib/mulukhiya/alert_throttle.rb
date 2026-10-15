module Mulukhiya
  # 鳴らす権利の獲得 (#4693 / #4722)。コントローラの `report_error` と、メディア変換の
  # 締切切れが使う。
  #
  # → **`SET NX EX` を再送なしで 1 回**撃つ。⚠⚠ **書けなかったら黙らせない。**
  # プロセス内の抑止へ倒す（`LocalAlertThrottle`）。**Redis が健全なら
  # クラスタ全体で 1 回、壊れていればプロセスごとに 1 回**鳴る。どちらでも
  # 「黙る」ことも「連打する」ことも無い。経緯は `ControllerErrorMethods#acquire_alert_slot`。
  module AlertThrottle
    def self.acquire(key, ttl)
      return Redis.new.acquire(key, ttl)
    rescue => e
      Logger.new.error(error: 'alert throttle unavailable', class: e.class.to_s, key:)
      return LocalAlertThrottle.acquire(key, ttl)
    end
  end
end
