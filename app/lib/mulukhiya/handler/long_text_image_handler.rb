module Mulukhiya
  class LongTextImageHandler < ImageHandler
    def disable?
      if Environment.production?
        return true unless today.month == 4
        return true unless today.day == 1
      end
      return super
    end

    def handle_pre_toot(payload, params = {})
      payload[attachment_field] ||= []
      self.payload = payload
      return if parser.command?
      return unless executable?
      return unless path = create_image(@status)
      payload[attachment_field].push(sns.upload(path, {response: :id}))
      parser.text = payload[text_field] = '.'
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
    ensure
      FileUtils.rm_rf(path)
    end

    def verbose?
      return true
    end

    def executable?
      return false if sns.max_media_attachments <= (payload[attachment_field] || []).count
      return text_length < payload[text_field]&.length
    end

    private

    def create_image(text)
      image = MiniMagick::Image.open(image_path)
      image.combine_options do |magick|
        magick.font font_path
        magick.gravity 'center'
        magick.pointsize handler_config(:font_size)
        magick.draw %(text 0,0 '#{prepare_text(text)}')
      end
      path = File.join(Environment.dir, 'tmp/media', "#{text.sha256}.png")
      image.write(path)
      return path
    rescue => e
      e.log
      return nil
    end

    def image_path
      return File.join(Environment.dir, handler_config(:image_file))
    end

    def font_path
      return File.join(Environment.dir, handler_config(:font_file))
    end

    def columns
      return handler_config(:columns)
    end

    def rows
      return handler_config(:rows)
    end

    def today
      return Date.today
    end

    def prepare_text(text)
      return text.scan(/.{1,#{columns}}/o)[0...rows].join("\n")
    end

    def text_length
      return handler_config(:text_length)
    end
  end
end
