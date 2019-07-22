module MulukhiyaTootProxy
  class MediaConvertHandler < Handler
    def handle_pre_upload(body, params = {})
      return unless @file = create_file(body)
      return unless convertable?
      body[:file][:org_tempfile] ||= body[:file][:tempfile]
      body[:file][:tempfile] = convert
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

    def create_file(body)
      return media_class.new(body[:file][:tempfile].path)
    rescue
      return nil
    end
  end
end
