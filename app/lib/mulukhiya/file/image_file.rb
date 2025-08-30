module Mulukhiya
  class ImageFile < MediaFile
    def values
      return {
        type:,
        mediatype:,
        subtype:,
        width:,
        height:,
        size:,
        length: size,
      }
    end

    alias to_h values

    def image
      return transform_icc(Vips::Image.new_from_file(path))
    end

    def pages
      return transform_icc(Vips::Image.new_from_file(path, n: -1))
    end

    def width
      return image.width
    end

    def height
      return image.height
    end

    def type
      return MIMEType.type(".#{image.get('vips-loader').sub(/load$/, '')}")
    rescue
      return MIMEType::DEFAULT
    end

    def mediatype
      return type.split('/').first
    end

    def subtype
      return type.split('/').last
    end

    def alpha?
      return false unless image?
      return true if image.bands == 4 && image.interpretation == :srgb
      return true if image.bands == 2 && image.interpretation == :b_w
      return false
    end

    def animated?
      return false unless image?
      return 1 < pages.get('n-pages')
    rescue
      return false
    end

    def gif?
      return type == 'image/gif'
    end

    def resize(pixel)
      dest = create_dest_path(f: __method__, p: pixel, type: type)
      resized = image.resize(pixel.to_f / long_side)
      resized.write_to_file(dest)
      return ImageFile.new(dest)
    end

    def trim!(fuzz = '20%')
      command = CommandLine.new(['mogrify', '-fuzz', fuzz, '-trim', '+repage', path])
      command.exec
    end

    def convert_type(type)
      return convert_animation_type(type) if animated?
      dest = create_dest_path(f: __method__, type:)
      image = Vips::Image.new_from_file(path)
      image.write_to_file(dest)
      return ImageFile.new(dest)
    end

    def convert_animation_type(type = 'image/gif')
      return unless animated?
      dest = create_dest_path(f: __method__, extname: MIMEType.extname(type))
      pages.write_to_file(dest)
      file = ImageFile.new(dest)
      return file if file.type == type
      return nil
    end

    private

    def transform_icc(image)
      if image.get_typeof('icc-profile-data').zero?
        image.colourspace(:srgb)
      else
        image.icc_transform(icc_path, embedded: true, intent: :relative)
      end
      return image
    end
  end
end
