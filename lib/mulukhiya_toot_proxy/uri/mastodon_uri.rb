require 'sanitize'

module MulukhiyaTootProxy
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
      template[:status] = Sanitize.clean(toot['content'].gsub(/<br.*?>/, "\n")).strip
      template[:attachments] = toot['media_attachments']
      template[:url] = toot['url']
      return template.to_s
    rescue => e
      Logger.new.info(Ginseng::Error.create(e).to_h.merge(toot_id: toot_id))
      raise Ginseng::GatewayError, e.message
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        @service = Mastodon.new(uri)
      end
      return @service
    end
  end
end
