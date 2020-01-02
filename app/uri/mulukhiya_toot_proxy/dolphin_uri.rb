module MulukhiyaTootProxy
  class DolphinURI < Ginseng::URI
    def note_id
      config = Config.instance
      config['/dolphin/patterns'].each do |pattern|
        next unless matches = path.match(Regexp.new(pattern['pattern']))
        return matches[1]
      end
      return nil
    end

    alias id note_id

    def to_md
      note = service.fetch_note(note_id)
      raise "Note '#{self}' not found" unless note
      template = Template.new('note_clipping.md')
      template[:account] = note['account']
      template[:status] = TootParser.new(note['content']).to_md
      template[:attachments] = note['media_attachments']
      template[:url] = note['url']
      return template.to_s
    rescue => e
      Logger.new.info(Ginseng::Error.create(e).to_h.merge(note_id: note_id))
      raise Ginseng::GatewayError, e.message, e.backtrace
    end

    def service
      unless @service
        uri = clone
        uri.path = '/'
        uri.query = nil
        uri.fragment = nil
        @service = DolphinService.new(uri)
      end
      return @service
    end
  end
end
