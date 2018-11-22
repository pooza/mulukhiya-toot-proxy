require 'addressable/uri'
require 'reverse_markdown'

module MulukhiyaTootProxy
  class MastodonURI < Addressable::URI
    def toot_id
      return nil unless matches = path.match(%r{/web/statuses/([[:digit:]]+)})
      return matches[1].to_i
    end

    def clip(params)
      toot = service.fetch_toot(toot_id)
      body = [ReverseMarkdown.convert(toot['content'])]
      body.push(toot['url'])
      body.concat(toot['media_attachments'].map{ |attachment| attachment['url']})
      params[:growi].push({path: params[:path], body: body.join("\n")})
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
