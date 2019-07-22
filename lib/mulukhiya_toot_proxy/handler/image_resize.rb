module MulukhiyaTootProxy
  class ImageResizeHandler < Handler
    def handle_pre_upload(body, params = {})
      return unless @file = create_file(body)
      return unless convertable?
      body[:file][:org_tempfile] ||= body[:file][:tempfile]
      body[:file][:tempfile] = @file.resize(@config['/handler/image_resize/pixel'])
      @result.push(src: body[:file][:org_tempfile].path, dest: body[:file][:tempfile].path)
    end

    def convertable?
      return false unless @file&.image?
      return @config['/handler/image_resize/pixel'] < @file.long_side
    end

    def create_file(body)
      return ImageFile.new(body[:file][:tempfile].path)
    rescue
      return nil
    end
  end
end
