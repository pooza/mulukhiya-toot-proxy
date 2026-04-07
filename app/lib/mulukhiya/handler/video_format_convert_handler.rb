module Mulukhiya
  class VideoFormatConvertHandler < MediaConvertHandler
    def convert
      return compatible_codec? ? file.convert_type(type) : file.transcode(type)
    ensure
      result.push(source: {type: file.type, video_codec: file.video_codec, pix_fmt: file.pix_fmt})
    end

    def convertable?
      return false unless file
      return false unless file.video?
      return true unless file.video_codec
      return true unless file.type == type
      return !compatible_codec?
    end

    def type
      return controller_class.default_video_type
    end

    def media_class
      return VideoFile
    end

    private

    def compatible_codec?
      codecs = controller_class.video_codecs
      return true unless codecs
      return false unless codecs.include?(file.video_codec)
      return compatible_pix_fmt?
    end

    def compatible_pix_fmt?
      fmt = file.pix_fmt
      return true unless fmt
      return fmt == 'yuv420p'
    end
  end
end
