module Mulukhiya
  class MastodonURI < Ginseng::URI
    def toot_id
      config = Config.instance
      config['/mastodon/patterns'].each do |pattern|
        next unless matches = path.match(Regexp.new(pattern['pattern']))
        return matches[1].to_i
      end
      return nil
    end

    alias id toot_id

    def to_md
      toot = service.fetch_toot(toot_id)
      raise "Toot '#{self}' not found" unless toot
      raise "Toot '#{self}' not found (#{toot['error']})" if toot['error']
      template = Template.new('toot_clipping.md')
      template[:account] = toot['account']
      template[:status] = TootParser.new(toot['content']).to_md
      template[:attachments] = toot['media_attachments']
      template[:url] = toot['url']
      return template.to_s
    rescue => e
      Logger.new.info(Ginseng::Error.create(e).to_h.merge(toot_id: toot_id))
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        @service = MastodonService.new(uri)
      end
      return @service
    end
  end
end
