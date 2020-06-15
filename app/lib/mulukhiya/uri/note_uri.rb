module Mulukhiya
  class NoteURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def note_id
      @config['/misskey/status/patterns'].each do |pattern|
        next unless matches = path.match(pattern['pattern'])
        return matches[1]
      end
      return nil
    end

    alias id note_id

    def valid?
      return absolute? && id.present?
    end

    def to_md
      note = Environment.status_class.first(uri: to_s) || Environment.status_class[id]
      raise "Note '#{self}' not found" unless note
      raise "Note '#{self}' not found" unless note.visible?
      template = Template.new('note_clipping.md')
      template[:account] = note.account
      template[:status] = NoteParser.new(note.text).to_md
      template[:attachments] = note.attachments.all
      template[:url] = note.uri
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        if Environment.dolphin?
          @service = DolphinService.new(uri)
        else
          @service = MisskeyService.new(uri)
        end
      end
      return @service
    end
  end
end
