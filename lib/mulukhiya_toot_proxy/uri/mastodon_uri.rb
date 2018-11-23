require 'addressable/uri'
require 'reverse_markdown'

module MulukhiyaTootProxy
  class MastodonURI < Addressable::URI
    def toot_id
      return nil unless matches = path.match(%r{/web/statuses/([[:digit:]]+)})
      return matches[1].to_i
    end

    def clip(params)
      params[:growi].push({path: params[:path], body: to_md})
    end

    def to_md
      toot = service.fetch_toot(toot_id)
      raise ExternalServiceError, "トゥートが取得できません。 #{self}" unless toot
      body = [
        '## アカウント',
        "[#{toot['account']['display_name']}](#{toot['account']['url']})",
        '## 本文',
        ReverseMarkdown.convert(toot['content']),
      ]
      if toot['media_attachments'].present?
        body.push('## メディア')
        body.concat(toot['media_attachments'].map{ |attachment| "- #{attachment['url']}"})
      end
      body.concat(['## URL', toot['url']])
      return body.join("\n")
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
