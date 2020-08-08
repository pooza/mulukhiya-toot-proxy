module Mulukhiya
  class VideoFile < MediaFile
    alias video? valid?

    def type
      return [mediatype, subtype].join('/') if mimemagic_invalid?
      return super
    end

    def mediatype
      return 'video' if mimemagic_invalid?
      return super
    end

    def subtype
      return "x-#{video_stream['codec_name'].downcase}" if mimemagic_invalid?
      return super
    end

    def width
      streams.each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['width'].present?
        return stream['width'].to_i
      end
      return nil
    end

    def height
      streams.each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['height'].present?
        return stream['height'].to_i
      end
      return nil
    end

    def duration
      streams.each do |stream|
        next unless stream['codec_type'] == default_mediatype
        next unless stream['duration'].present?
        return stream['duration'].to_f
      end
      return nil
    end

    def convert_format(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['ffmpeg', '-y', '-i', path, dest])
      command.exec unless File.exist?(dest)
      return VideoFile.new(dest)
    end

    def streams
      unless @streams
        command = CommandLine.new([
          'ffprobe', '-v', 'quiet',
          '-print_format', 'json',
          '-show_streams',
          path
        ])
        command.exec
        @streams = JSON.parse(command.stdout)['streams']
      end
      return @streams
    end

    alias detail_info streams

    def mimemagic_invalid?
      return mimemagic&.mediatype != 'video' && video_stream.present?
    end

    def video_stream
      return streams.select {|v| v['codec_type'] == 'video'}.first
    end

    def audio_stream
      return streams.select {|v| v['codec_type'] == 'audio'}.first
    end
  end
end
