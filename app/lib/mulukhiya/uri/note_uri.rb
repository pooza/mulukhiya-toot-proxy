module Mulukhiya
  class NoteURI < Ginseng::Fediverse::NoteURI
    include Package
    include SNSMethods

    def local?
      return true if note.dig('user', 'host').empty?
      return true if acct.host == Environment.domain_name
      return false
    rescue => e
      e.log
      return false
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = account
      template[:status] = parser.to_md
      template[:attachments] = (note['files'] || []).map(&:deep_symbolize_keys)
      template[:url] = self
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def parser
      unless @parser
        @parser = NoteParser.new(note&.dig('text') || '')
        @parser.service = service
      end
      return @parser
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        if Environment.misskey_type?
          @service = sns_class.new(uri)
        else
          @service = MisskeyService.new(uri)
        end
        @service.token = nil
      end
      return @service
    end

    def subject
      unless @subject
        @subject = note['cw'] if note['cw'].present?
        @subject ||= note['text']
        @subject.sanitize!
        Ginseng::URI.scan(@subject.dup) {|uri| @subject.gsub!(uri.to_s, '')}
        @subject.gsub!(/[\s[:blank:]]+/, ' ')
      end
      return @subject
    end

    def account
      unless @account
        @account = note['user'].clone
        @account['display_name'] = @account['name'] || "@#{@account['username']}"
        @account['url'] = service.create_uri("/@#{@account['username']}")
      end
      return @account
    end
  end
end
