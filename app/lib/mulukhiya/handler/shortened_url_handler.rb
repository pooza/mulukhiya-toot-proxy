module Mulukhiya
  class ShortenedURLHandler < URLHandler
    MAX_REDIRECTS = 8

    def rewrite(uri)
      source = Ginseng::URI.parse(uri.to_s)
      dest = resolve_redirects(source)
      @status = @status.sub(source.to_s, dest.to_s)
      return dest
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return uri
    end

    def rewritable?(uri)
      uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
      return true if uri.host == 't.co' # TwitterのURL短縮サービスは常にリダイレクト
      return domains.member?(uri.host)
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: uri.to_s)
      return false
    end

    private

    # ⚠ 各ホップを必ず SSRF allowlist に通す (#4535)。
    #
    # ホップ追従は Ginseng::HTTP の host_validator に任せられない。あちらは
    # 追従まで肩代わりして最終レスポンスだけ返すので、**最終 URL が取れず**
    # 短縮 URL の展開そのものが成立しない。追うのがこちらである以上、検証も
    # こちらの責務になる。
    #
    # 通さないと、rewritable? が無条件で許す t.co の短縮 URL 1 本で
    # `http://169.254.169.254/...` 等へ GET を撃たせられる（本文は捨てるので
    # ブラインドだが、内部エンドポイントへの到達は成立する）。#4410 / #4523 の
    # 掃討の続き。
    def resolve_redirects(source)
      return source unless address = permitted_address(source)
      dest = source.clone
      redirects = 0
      while redirects < MAX_REDIRECTS
        next_uri, status = fetch_redirect(dest, address)
        break unless next_uri
        break unless (status / 100) == 3
        # ⚠ GET を撃たないだけでは足りない。dest にしてしまうと、投稿本文が
        # 内部 URL へ書き換わったまま連合に流れる。
        break unless next_address = permitted_address(next_uri)
        dest = next_uri
        address = next_address
        redirects += 1
      end
      return dest
    end

    # 検証は「GET する直前の 1 回」で足りる。あるホップの next_uri は次の
    # ホップの src なので、ここで通したものだけが fetch_redirect へ渡る。
    #
    # ⚠ **戻り値のアドレスを捨てない** (#4524)。名前で検証して名前で接続すると、
    # 権威 DNS を握った相手が検証時だけ公開 IP アドレスを返し、GET のときに 127.0.0.1 を
    # 返せる。ここは自前でホップを追う経路なので、pinning も自前で渡す必要がある。
    def permitted_address(uri)
      address = RemoteHost.validator.call(uri.host.to_s)
      return address if address
      errors.push(
        class: Ginseng::GatewayError.to_s,
        message: "Rejected host '#{uri.host}'",
        url: uri.to_s,
      )
      return nil
    end

    def fetch_redirect(src, address)
      options = Ginseng::PinnedAddressAdapter.pin({follow_redirects: false}, address)
      response = http.get(src, options)
      return [nil, nil] unless location = response.headers['location']
      dest = normalize_location(src, location)
      return [nil, nil] unless dest&.host
      return [dest, response.code.to_i]
    rescue => e
      errors.push(class: e.class.to_s, message: e.message, url: dest.to_s)
      return [nil, nil]
    end

    def domains
      return handler_config(:domains) || []
    end

    def normalize_location(base_uri, location)
      loc = location.to_s.strip
      return nil if loc.empty?
      return parse_scheme_relative(base_uri, loc) if scheme_relative?(loc)
      parsed = parse_absolute(loc)
      return parsed if parsed&.host
      return parse_absolute_path(base_uri, loc) if absolute_path?(loc)
      return parse_relative_path(base_uri, loc)
    end

    def scheme_relative?(loc)
      return loc.start_with?('//')
    end

    def absolute_path?(loc)
      return loc.start_with?('/')
    end

    def parse_scheme_relative(base_uri, loc)
      return Ginseng::URI.parse("#{base_uri.scheme}:#{loc}")
    end

    def parse_absolute(loc)
      return Ginseng::URI.parse(loc)
    rescue
      return nil
    end

    def parse_absolute_path(base_uri, loc)
      return Ginseng::URI.parse("#{base_uri.scheme}://#{base_uri.host}#{loc}")
    end

    def parse_relative_path(base_uri, loc)
      dir = normalize_dir(base_uri.path.to_s)
      url = "#{base_uri.scheme}://#{base_uri.host}#{dir}/#{loc}".squeeze('/').sub(':/', '://')
      return Ginseng::URI.parse(url)
    end

    def normalize_dir(path)
      dir = path.end_with?('/') ? path : File.dirname(path)
      return '/' if dir == '.'
      return dir
    end
  end
end
