module Mulukhiya
  class RemoteHost
    DEFAULT_DNS_TIMEOUT = 3

    # ⚠⚠ **判定の本体は `Ginseng::PublicHost`（ginseng-core 2.1.0〜）にある (#4790)。**
    # ここで持っていた予約レンジの表は 2 巡続けて漏れた（文書用レンジ・6to4 / Teredo・
    # site-local・`2000::/3` の外の予約）。上流は IPv4 を IANA の Special-Purpose Address
    # Registry に合わせ、IPv6 は「落とすレンジを並べる」のをやめて**グローバルユニキャスト
    # （`2000::/3`）の外を丸ごと拒否**している。表をこちらへ写し直さないこと。
    #
    # こちらに残すのは、モロヘイヤの都合で決まるものだけ:
    # 設定から読む DNS タイムアウト・拒否理由の warn ログ・`validator` の差し替え口・
    # `unpinned_validator`・`validate!`。

    def self.public?(host, resolver: method(:resolve_addresses))
      return allowed_address(host, resolver:).present?
    end

    # 許可できるなら**接続に使う IP アドレス**を、拒否なら nil を返す (#4524)。
    #
    # ⚠ **真偽値ではなくアドレスを返すのが肝。**名前で検証して名前で接続すると、
    # 権威 DNS を握った相手が検証時だけ公開 IP アドレスを返し、接続時に 127.0.0.1 を
    # 返せる（DNS リバインディング / TOCTOU）。ここで通した IP アドレスをそのまま接続先へ
    # 固定する（pinning は pooza/ginseng-core#503）。
    #
    # ⚠ **1 本に固定するので Net::HTTP の複数アドレスへのフォールバックは効かなく
    # なる。**A レコードが複数あって先頭だけ落ちている相手は取得できない。
    # allowlist の対象は管理者が設定した少数の URL なので、この不便より
    # 「検証した先に繋ぐ」ほうを採る。
    def self.allowed_address(host, resolver: method(:resolve_addresses))
      return Ginseng::PublicHost.allowed_address(host.to_s, resolver: logging_resolver(resolver))
    end

    # 名前解決の失敗（DNS 障害・タイムアウト等の環境要因）を warn に残してから上へ渡す。
    #
    # ⚠ 上流は fail-closed で nil（= 拒否）を返すが、**ログは出さない。**運用ミス
    # （未到達ホスト等）と攻撃検知を切り分けるための行なので、こちらで残す。
    # ⚠ IPAddr::Error 等のロジックバグは上流も握らない。呼び出し元へ伝わり Sentry に出る。
    def self.logging_resolver(resolver)
      return lambda do |host|
        resolver.call(host)
      rescue *Ginseng::PublicHost::RESOLUTION_ERRORS => e
        Logger.new.warn(remote_host: {host:, error: e.class.name, message: e.message})
        raise
      end
    end

    # Ginseng::HTTP#get の host_validator へ渡す callable (#4410)。
    # リダイレクトの各ホップがこれを通る。
    #
    # ⚠ **返すのは真偽値ではなく IP アドレス**（拒否なら nil）。ginseng-core は
    # 文字列が返るとその IP アドレスへ接続を固定する (pooza/ginseng-core#503)。名前で
    # 検証して名前で接続していると DNS リバインディングで抜けられる (#4524)。
    #
    # ⚠ writer はテストの差し替え専用。実行時に緩めてはいけない。差し替えた
    # テストは teardown で必ず元へ戻すこと（残すと以後のテストで SSRF ガードが
    # 効かなくなり、守れているつもりの緑になる）。
    def self.validator
      @validator ||= ->(host) {allowed_address(host)}
      return @validator
    end

    class << self
      attr_writer :validator
    end

    # pinning **しない** validator (#4576)。真偽値を返すので ginseng-core は
    # 各ホップのホスト検証だけを行い、接続先は名前解決に任せる。
    #
    # ⚠ **CDN 相手に pinning を効かせないためのもの。**大手 CDN は複数の A
    # レコードを返してアドレスをローテーションするので、1 本へ固定すると
    # 「選んだアドレスだけ落ちている」ときに取得できず、添付が黙って落ちる
    # (#4524 のトレードオフ)。DNS リバインディングは防げないが、**検証を
    # 一切しない状態よりは強い**（リダイレクト先が内部でも追従しなくなる）。
    #
    # ⚠ **判定の実体は validator に委譲する。**テストが validator を差し替えたら
    # こちらも一緒に効く必要がある。
    def self.unpinned_validator
      return ->(host) {validator.call(host).present?}
    end

    # allowlist を通らないホストで GatewayError を投げる (#4535)。
    #
    # HEAD プリフライトの rescue は「HEAD 非対応・一過性障害 = 判定不能」を
    # GET へ倒すためのもの。allowlist 拒否まで同じ rescue が飲むと
    # 「プリフライトが true = GET してよい」が成り立たなくなり、GET 側の
    # host_validator が外れた瞬間に無検証へ戻る。拒否は HEAD を撃つ前に
    # ここで確定させ、URL 単位の rescue へ渡す（拒否 1 件につきログも 1 本）。
    def self.validate!(uri)
      host = uri.respond_to?(:host) ? uri.host.to_s : uri.to_s
      return true if validator.call(host)
      raise Ginseng::GatewayError, "Rejected host '#{host}'"
    end

    # Addrinfo.getaddrinfo は timeout を持てず、攻撃者が応答を引き延ばす権威
    # DNS を立てると Sinatra リクエストスレッド (Puma 5 本) を飽和させられる。
    #
    # ⚠ **締め切りは名前解決の全体に 1 本**（上流の `Timeout.timeout`・#4790）。
    # `Resolv::DNS#timeouts=` は問い合わせ 1 回ぶんの上限でしかなく、応答しない
    # ネームサーバーが 3 台あると「2 種別 × 3 台 × timeout」かかっていた（3 秒の設定で 18 秒）。
    def self.resolve_addresses(host)
      return Ginseng::PublicHost.resolve_addresses(host, timeout: dns_timeout)
    end

    def self.dns_timeout
      return Config.instance['/remote_host/dns/timeout'] || DEFAULT_DNS_TIMEOUT
    end
  end
end
