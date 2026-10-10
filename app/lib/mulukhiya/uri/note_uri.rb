module Mulukhiya
  class NoteURI < Ginseng::Fediverse::NoteURI
    include Package
    include SNSMethods

    def local?
      return true if note.dig('user', 'host').empty?
      return true if acct.host == Environment.domain_name
      return false
    rescue => e
      e.log
      return false
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = account
      template[:status] = parser.to_md
      template[:attachments] = (note['files'] || []).map(&:deep_symbolize_keys)
      template[:url] = self
      return template.to_s
    rescue => e
      # 内側が既に GatewayError（上流の取得失敗）ならレスポンスを保ったまま
      # ForeignGatewayError へ付け替える (#4537)。⚠ ここで失敗しているのは
      # **引用元の他人のサーバー**であって自分の上流ではないので、#4480 の透過に
      # 乗せてはいけない。包み直さないのは上流のレスポンスを落とさないため。
      raise ForeignGatewayError.wrap(e) if e.is_a?(Ginseng::GatewayError)
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def parser
      unless @parser
        @parser = NoteParser.new(note.fetch('text', ''))
        @parser.service = service
      end
      return @parser
    end

    # 投稿の取得先ホストの検証（ginseng-fediverse 5.0.0・#4813）。
    #
    # 🔴 URL は利用者が書く（クリップのコマンド・引用）。検証が無いと `http://127.0.0.1:<port>/@a/1` の
    # ような URL で、ローカルのサーバーへ要求が届く（pooza/ginseng-fediverse#306）。
    # ⚠ gem の既定（`Ginseng::PublicHost.validator`）ではなく `RemoteHost.validator` を返す。
    # 判定の本体は同じで、設定の DNS タイムアウトと、拒否の warn ログが付く（gem の既定は拒否を残さない）。
    # ⚠⚠ **自サーバーの投稿も公開 URL 経由で取る。**自ドメインが内部アドレスに解決される構成
    # （split DNS など）では、自サーバーの投稿のクリップと `to_md` が `Rejected host` になる。
    # 外すときは **scheme・ホスト・ポートの 3 つとも**比べること（ホスト名だけで外すと、
    # `http://<自ドメイン>:6379/@a/1` で自サーバーの任意のポートへ要求が出る）。
    def host_validator
      return RemoteHost.validator
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        if Environment.misskey_type?
          @service = sns_class.new(uri)
        else
          @service = MisskeyService.new(uri)
        end
        @service.token = nil
      end
      return @service
    end

    def account
      unless @account
        @account = note['user'].clone
        @account['display_name'] = @account['name'] || "@#{@account['username']}"
        @account['url'] = service.create_uri("/@#{@account['username']}")
      end
      return @account
    end
  end
end
