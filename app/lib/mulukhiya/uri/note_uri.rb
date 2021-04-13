module Mulukhiya
  class NoteURI < Ginseng::Fediverse::NoteURI
    include Package
    include SNSMethods

    def local?
      return true if note['user']['host'].empty?
      return true if acct.host == Environment.domain_name
      return false
    rescue => e
      logger.error(error: e)
      return false
    end

    def to_md
      template = Template.new('status_clipping.md')
      template[:account] = account
      template[:status] = parser.to_md
      template[:attachments] = note['files']
      template[:url] = self
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def subject
      return note['text'].sanitize
    end

    def parser
      unless @parser
        @parser = NoteParser.new(note['text'])
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
