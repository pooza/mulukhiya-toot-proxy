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
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def subject
      unless @subject
        @subject = toot['spoiler_text'] if toot['spoiler_text'].present?
        @subject ||= toot['content']
        @subject.sanitize!
        Ginseng::URI.scan(@subject.dup) {|uri| @subject.gsub!(uri.to_s, '')}
        @subject.gsub!(/[\s[:blank:]]+/, ' ')
      end
      return @subject
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
