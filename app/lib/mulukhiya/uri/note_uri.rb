module Mulukhiya
  class NoteURI < Ginseng::URI
    def initialize(options = {})
      super
      @config = Config.instance
      @logger = Logger.new
    end

    def note_id
      @config['/parser/note/patterns'].each do |pattern|
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
      return note.local?
    end

    def to_md
      template = Template.new('note_clipping.md')
      template[:account] = note.account
      template[:status] = NoteParser.new(note.text).to_md
      template[:attachments] = note.attachments
      template[:url] = note.uri
      return template.to_s
    rescue => e
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    private

    def note
      unless @note
        @note = Environment.status_class.first(uri: to_s)
        @note ||= Environment.status_class[id] if host == Environment.domain_name
        raise "Note '#{self}' not found" unless @note
        raise "Note '#{self}' not found" unless @note.visible?
      end
      return @note
    end
  end
end
