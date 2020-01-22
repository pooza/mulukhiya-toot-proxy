module Mulukhiya
  class MediaConvertHandler < Handler
    def handle_pre_upload(body, params = {})
      return unless @source = source_file(body)
      return unless convertable?
      return unless @dest = convert
      body[:file][:org_tempfile] ||= body[:file][:tempfile]
      body[:file][:tempfile] = @dest
      @result.push(src: body[:file][:org_tempfile].path, dest: body[:file][:tempfile].path)
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

    def source_file(body)
      return media_class.new(body[:file][:tempfile].path)
    rescue
      return nil
    end
  end
end
