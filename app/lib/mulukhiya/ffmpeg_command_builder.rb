module Mulukhiya
  class FFmpegCommandBuilder
    include Package

    def self.remux_video(src, dest)
      return CommandLine.new([
        'ffmpeg', '-y', '-err_detect', 'explode', '-i', src,
        '-map', '0:v:0', '-map', '0:a:0?', '-map', '0:s?',
        '-c', 'copy', '-movflags', '+faststart',
        '-map_metadata', '0', '-map_chapters', '0', dest
      ])
    end

    def self.transcode_video(src, dest, crf: null, preset: null)
      crf ||= config['/ffmpeg/crf']
      preset ||= config['/ffmpeg/preset']
      return CommandLine.new([
        'ffmpeg', '-y', '-err_detect', 'explode', '-i', src,
        '-map', '0:v:0', '-map', '0:a:0?', '-map', '0:s?',
        '-c:v', 'libx264', '-preset', preset, '-crf', crf.to_s,
        '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1', '-g', '120',
        '-c:a', 'aac', '-b:a', '160k', '-ar', '48000', '-ac', '2',
        '-c:s', 'mov_text',
        '-movflags', '+faststart', '-map_metadata', '0', '-map_chapters', '0', dest
      ])
    end

    def self.remux_audio(src, dest)
      return CommandLine.new([
        'ffmpeg', '-y', '-err_detect', 'explode', '-i', src,
        '-map', '0:a:0', '-c', 'copy', '-map_metadata', '0', '-id3v2_version', '3', dest
      ])
    end

    def self.transcode_audio(src, dest, bitrate: null)
      bitrate ||= config['/ffmpeg/audio/bitrate']
      return CommandLine.new([
        'ffmpeg', '-y', '-err_detect', 'explode', '-i', src,
        '-map', '0:a:0', '-c:a', 'libmp3lame', '-b:a', "#{bitrate}k",
        '-map_metadata', '0', '-id3v2_version', '3', dest
      ])
    end

    def self.probe_video(src)
      return CommandLine.new([
        'ffprobe', '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name,pix_fmt,width,height,duration,avg_frame_rate',
        '-of', 'json',
        src
      ])
    end

    def self.probe_audio(src)
      return CommandLine.new([
        'ffprobe', '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=codec_name,duration,sample_rate,channels,bit_rate',
        '-of', 'json',
        src
      ])
    end

    def self.probe_container(src)
      return CommandLine.new([
        'ffprobe', '-v', 'error',
        '-show_entries', 'format=duration,bit_rate,format_name',
        '-of', 'json',
        src
      ])
    end
  end
end
