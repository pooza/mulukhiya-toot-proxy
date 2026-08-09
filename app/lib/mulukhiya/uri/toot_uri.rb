module Mulukhiya
  class TootURI < Ginseng::Fediverse::TootURI
    include Package
    include SNSMethods

    def local?
      return Ginseng::URI.parse(toot.dig('account', 'url')).host == Environment.domain_name
    rescue => e
      e.log
      return false
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = toot['account']
      template[:status] = TootParser.new(toot['content']).to_md
      template[:attachments] = (toot['media_attachments'] || []).map(&:deep_symbolize_keys)
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

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        if Environment.mastodon_type?
          @service = sns_class.new(uri)
        else
          @service = MastodonService.new(uri)
        end
        @service.token = nil
      end
      return @service
    end
  end
end
