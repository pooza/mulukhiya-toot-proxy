module Mulukhiya
  module AttachmentMethods
    include SNSMethods

    def mediatype
      return type.split('/').first
    end

    def width
      return meta&.fetch(:width, nil)
    end

    def height
      return meta&.fetch(:height, nil)
    end

    def pixel_size
      return nil unless width
      return nil unless height
      return "#{width}x#{height}"
    end

    def duration
      return nil unless meta
      return nil unless meta[:duration]
      return meta[:duration].to_f.round(2)
    end

    def uri
      return create_uri(:original)
    end

    def thumbnail_uri
      return create_uri(:small)
    end

    def meta
      storage = MediaMetadataStorage.new
      storage.push(uri) unless storage.key?(uri)
      return storage[uri]
    rescue => e
      e.log(path:)
      return nil
    end

    def size_str
      return nil unless size
      ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'].freeze.each_with_index do |unit, i|
        unitsize = 1024.pow(i)
        return "#{(size.to_f / unitsize).floor.commaize}#{unit}B" if size < unitsize * 1024 * 2
      end
      raise 'Too large'
    rescue => e
      e.log(size:, attachment: id)
      return size
    end

    def feed_entry
      return {
        link: uri.to_s,
        title: [name, "(#{size_str})", description].compact.join(' '),
        author: account.display_name,
        created_at: date,
        date:,
      }
    end

    def to_h
      return values.deep_symbolize_keys.merge(
        created_at: date&.getlocal&.strftime('%Y/%m/%d %H:%M:%S'),
        duration:,
        file_name: name,
        file_size_str: size_str,
        id:,
        mediatype:,
        pixel_size:,
        thumbnail_url: thumbnail_uri.to_s,
        type:,
        url: uri.to_s,
      ).compact
    end
  end
end
