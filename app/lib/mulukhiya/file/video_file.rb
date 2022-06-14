module Mulukhiya
  class VideoFile < MediaFile
    def values
      return {
        type:,
        mediatype:,
        subtype:,
        duration:,
        width:,
        height:,
        size:,
        length: size,
      }
    end

    alias to_h values

    def width
      return video_stream.fetch('width').to_i
    rescue => e
      e.log(file: path)
      return nil
    end

    def height
      return video_stream.fetch('height').to_i
    rescue => e
      e.log(file: path)
      return nil
    end

    def duration
      duration = video_stream.fetch('duration', nil)
      duration ||= video_stream.dig('tags', 'DURATION')
      return duration.to_f
    rescue => e
      e.log(file: path)
      return nil
    end
  end
end
