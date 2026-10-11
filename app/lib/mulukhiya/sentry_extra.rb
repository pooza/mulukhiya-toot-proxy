module Mulukhiya
  # alert の付帯情報を Sentry のイベントへ載せる形にする (#4745)。
  #
  # ⚠ **他者のサーバーは syslog を見られない。**DSN を合流しているので、付帯情報が
  # Sentry に出ないと「何本のソースが取れなかったか」も答えられない（`-2Q` で踏んだ）。
  #
  # 🔴 **そのまま `extra:` に渡してはいけない。**`Mulukhiya.scrub_sentry_event` が伏せるのは
  # 例外のメッセージだけで、extra は素通りする。syslog と同じ `Logger` のマスク
  # （キー名・URL のクエリ）に加えて、`LogScrubber`（本文系・OAuth コード・ボディの `i`）も通す。
  class SentryExtra
    include LogScrubber

    def self.create(values)
      return new.create(values)
    end

    # ⚠⚠ **fail closed。**伏せ字の途中で落ちたら中身は送らない。ただし例外は上げない
    # （上げると呼び出し側の `rescue nil` で**イベントごと消える**）。
    def create(values)
      return {} if values.blank?
      extra = Logger.new.create_message(scrub_log_params(stringify(values.to_h)))
      return extra.is_a?(Hash) ? extra : {values: extra}
    rescue
      return {scrub_failed: true}
    end

    private

    # ⚠ **マスクは Hash / Array / String しか潜らない。**URI オブジェクトなどをそのまま渡すと、
    # クエリのトークンが伏せられずに残る。先に文字列へ落とす。
    def stringify(value)
      case value
      when Hash then value.transform_values {|v| stringify(v)}
      when Array then value.map {|v| stringify(v)}
      when String, Symbol, Numeric, true, false, nil then value
      else value.to_s
      end
    end
  end
end
