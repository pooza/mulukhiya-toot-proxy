module Mulukhiya
  # PieFed へのクリップ。HTTP だけをモロヘイヤのものへ差し替える (#4750)。
  #
  # ⚠⚠ **`include Package` はしない。**`config_class` まで `Mulukhiya::Config` に替わり、
  # gem が読む `/piefed/api/version` / `/piefed/community/types` / `/piefed/subject/max_length` が
  # 引けなくなる（モロヘイヤの設定には無い）。
  # 🔴 ginseng-piefed 0.1.2 で `Service` が `http_class` を通すようになったが、`Ginseng::Piefed::Service`
  # を直に作っている限り既定の `Ginseng::HTTP` のまま。ここで上書きして初めて、モロヘイヤの
  # ログのマスク・再送上限・User-Agent が PieFed 宛にも掛かる。
  class PiefedService < Ginseng::Piefed::Service
    def http_class
      return HTTP
    end
  end
end
