require 'rest-client'

module Mulukhiya
  class MediaConvertHandler < Handler
    def handle_pre_upload(body, params = {})
      return unless @source = source_file(body)
      return unless convertable?
      return unless @dest = convert
      body[:file][:org_tempfile] ||= body[:file][:tempfile]
      body[:file][:tempfile] = @dest
    end

    def handle_pre_thumbnail(body, params = {})
      return unless @source = source_file(body, :thumbnail)
      return unless convertable?
      return unless @dest = convert
      body[:thumbnail][:org_tempfile] ||= body[:thumbnail][:tempfile]
      body[:thumbnail][:tempfile] = @dest
    end

    def convert
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def convertable?
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def media_class
      return ImageFile
    end

    def source_file(body, key = :file)
      return media_class.new(body[key][:tempfile].path)
    rescue
      return nil
    end
  end
end
