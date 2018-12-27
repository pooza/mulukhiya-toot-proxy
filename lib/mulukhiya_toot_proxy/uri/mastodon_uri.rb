require 'addressable/uri'

module MulukhiyaTootProxy
  class MastodonURI < Addressable::URI
    def toot_id
      config = Config.instance
      config['/mastodon/patterns'].each do |pattern|
        next unless matches = path.match(Regexp.new(pattern['pattern']))
        return matches[1].to_i
      end
      return nil
    end

    def id
      return toot_id
    end

    def to_md
      toot = service.fetch_toot(toot_id)
      raise ExternalServiceError, "Toot '#{self}' not found" unless toot
      raise ExternalServiceError, "Toot '#{self}' not found" if toot['error']
      account = toot['account']
      template = Template.new('toot_clipping.md')
      template[:account] = account
      template[:status] = ReverseMarkdown.convert(toot['content'])
      template[:attachments] = toot['media_attachments']
      template[:url] = toot['url']
      return template.to_s
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
