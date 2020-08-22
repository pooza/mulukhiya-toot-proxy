module Mulukhiya
  class NoteURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def note_id
      @config['/parser/note/url/patterns'].each do |pattern|
        next unless matches = path.match(pattern)
        return matches[1]
      end
      return nil
    end

    alias id note_id

    def valid?
      return absolute? && id.present?
    end

    def local?
      return true if note['user']['host'].empty?
      return true if acct.host == Environment.domain_name
      return false
    rescue => e
      @logger.error(e)
      return false
    end

    def publicize!
      self.path = "/notes/#{id}" if id
      return self
    end

    def publicize
      return clone.publicize!
    end

    def visibility
      return note['visibility']
    end

    def public?
      return visibility == 'public'
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
        if ['misskey', 'meisskey', 'dolphin'].member?(Environment.controller_name)
          @service = Environment.sns_class.new(uri)
        else
          @service = MisskeyService.new(uri)
        end
        @service.token = nil
      end
      return @service
    end

    def note
      unless @note
        @note = service.fetch_status(id)
        raise "Note '#{self}' not found" unless @note
        raise "Note '#{self}' is invalid (#{note['error']['message']})" if note['error']
      end
      return @note
    end

    alias status note

    def account
      unless @account
        @account = note['user'].clone
        @account['display_name'] = @account['name']
        @account['url'] = service.create_uri("/@#{@account['username']}")
      end
      return @account
    end
  end
end
