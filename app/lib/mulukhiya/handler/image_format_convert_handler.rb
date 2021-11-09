module Mulukhiya
  class ImageFormatConvertHandler < MediaConvertHandler
    def convert
      return file.convert_type(type)
    ensure
      result.push(source: {type: file.type})
    end

    def convertable?
      return false unless file
      return false unless file.image?
      return false if file.type == type
      return false if file.type == 'image/gif'
      return false if detect_alpha? && file.alpha?
      return false if file.animated?
      return true
    end

    def detect_alpha?
      return config['/handler/image_format_convert/alpha'] == true
    end

    def schema
      return super.deep_merge(
        type: 'object',
        properties: {
          aplha: {type: 'boolean'},
        },
      )
    end

    def type
      return controller_class.default_image_type
    end
  end
end
