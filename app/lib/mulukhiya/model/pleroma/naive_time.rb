module Mulukhiya
  module Pleroma
    # Akkoma（Ecto）の `timestamp without time zone` の列を、UTC として読み直す (#4864)。
    #
    # ⚠⚠ **Akkoma はタイムゾーンの無い列に UTC を入れる**（`oauth_tokens.valid_until`・`users.inserted_at` など）。
    # モロヘイヤは Sequel のタイムゾーンを設定していないので、**読んだ値はサーバーのローカル時刻（JST）として
    # 解釈され、9 時間早くなる**（`2126-09-21 22:19:28` が `+0900` 付きで返る）。
    # ⚠ `Sequel.database_timezone = :utc` を全体に掛けない。Mastodon・Misskey の時刻の列の読み方まで変わる。
    # 直すのは Pleroma 系のモデルの、時刻を比べる・見せるところだけ。
    #
    # ⚠ 年月日と時分秒（端数を含む）を取り出して UTC として組み直すだけなので、**既に UTC で返った値を
    # 渡しても変わらない**。⚠ ただし、Sequel が UTC からローカルへ正しく変換した値（`database_timezone = :utc`
    # かつ `application_timezone = :local`）を渡すとずれる。その設定にしたら、これは要らなくなる。
    module NaiveTime
      def self.utc(time)
        return nil if time.nil?
        seconds = time.sec + time.subsec
        return Time.utc(time.year, time.month, time.day, time.hour, time.min, seconds)
      end
    end
  end
end
