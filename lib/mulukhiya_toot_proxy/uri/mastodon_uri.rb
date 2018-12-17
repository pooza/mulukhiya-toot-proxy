require 'zlib'
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
      raise ExternalServiceError, "Toot '#{self}' not found" unless toot
      account = toot['account']
      template = Template.new('toot_clipping.md')
      template[:account] = account
      template[:status] = html2md(toot['content'])
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

    private

    def html2md(text)
      text = ReverseMarkdown.convert(text)
      text.gsub!(/```.*?```/m) do |block|
        block.gsub('\_', '_').gsub('\*', '*').gsub('\<', '<').gsub('\>', '>')
      end
      return text
    end
  end
end
