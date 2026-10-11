module Mulukhiya
  # 投稿の取得先ホストの検証（ginseng-fediverse 5.0.0・#4813）。`TootURI` / `NoteURI` に混ぜる。
  #
  # 🔴 URL は利用者が書く（クリップのコマンド・引用）。検証が無いと `http://127.0.0.1:<port>/@a/1` の
  # ような URL で、ローカルのサーバーへ要求が届く（pooza/ginseng-fediverse#306）。
  # ⚠ gem の既定（`Ginseng::PublicHost.validator`）ではなく `RemoteHost.validator` を返す。
  # 判定の本体は同じで、設定の DNS タイムアウトと、**名前解決に失敗したとき**の warn ログが付く。
  # ⚠ IP アドレスの直書き・内部アドレスに解決される名前の拒否は、ここでも gem でもログに残らない。
  # 痕跡は呼び出し側が残す（`PiefedClippingWorker` の `rejected host`）。
  module StatusHostValidationMethods
    # ⚠ nil を返すと検証しない。**自サーバーの URL だけ**外す。
    #
    # モロヘイヤは自サーバーの投稿も URL 経由で取る（クリップは `local?` の前に取得する。`Status#to_md` も）。
    # 自サーバーの URL が内部アドレスに解決される構成（split DNS・`/etc/hosts` で内向き・
    # fedi-test-harness の `http://localhost:3000`）で検証を掛けると、自サーバーの投稿が毎回
    # `Rejected host` になる。宛先は、もともとトークンつきで話している自サーバーそのもの。
    def host_validator
      return nil if own_origin?
      return RemoteHost.validator
    end

    # 設定の自サーバーの URL と、**scheme・ホスト・ポートの 3 つとも**同じか。
    #
    # 🔴🔴 **ホスト名だけを比べない。**`http://<自ドメイン>:6379/@a/1` のような URL で、
    # 自サーバーの任意のポートへ要求が出る。外すのが要る構成は、ちょうど内部のポートに届く構成でもある。
    # ⚠ `host` は書かれたままの字面なので、比べるのは `normalized_host`。
    # ⚠ 分からないときは false（＝検証する側）へ倒す。
    def own_origin?
      own = Ginseng::URI.parse(Config.instance["/#{Environment.controller_name}/url"])
      return false unless own&.absolute?
      return scheme == own.scheme &&
          inferred_port == own.inferred_port &&
          normalized_host == own.normalized_host
    rescue => e
      e.log
      return false
    end
  end
end
