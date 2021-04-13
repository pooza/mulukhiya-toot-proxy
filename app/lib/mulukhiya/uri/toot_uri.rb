module Mulukhiya
  class TootURI < Ginseng::Fediverse::TootURI
    include Package
    include SNSMethods

    def local?
      return Ginseng::URI.parse(toot['account']['url']).host == Environment.domain_name
    rescue => e
      logger.error(error: e)
      return false
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = toot['account']
      template[:status] = TootParser.new(toot['content']).to_md
      template[:attachments] = toot['media_attachments']
      template[:url] = self
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def subject
      return toot['content'].sanitize
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
