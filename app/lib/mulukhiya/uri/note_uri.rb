module Mulukhiya
  class NoteURI < Ginseng::URI
    def initialize(options = {})
      super(options)
      @config = Config.instance
      @logger = Logger.new
    end

    def note_id
      @config['/dolphin/note/patterns'].each do |pattern|
        next unless matches = path.match(Regexp.new(pattern['pattern']))
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
      note = Environment.sns_class.new.fetch_note(note.id)
      raise "Note '#{self}' not found" unless note
      template = Template.new('note_clipping.md')
      template[:account] = note['account']
      template[:status] = NoteParser.new(note['text']).to_md
      template[:attachments] = note['attachments']
      template[:url] = note['uri']
      return template.to_s
    rescue => e
      @logger.info(Ginseng::Error.create(e).to_h.merge(note_id: note_id))
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        @service = Environment.sns_class.new(uri)
      end
      return @service
    end
  end
end
