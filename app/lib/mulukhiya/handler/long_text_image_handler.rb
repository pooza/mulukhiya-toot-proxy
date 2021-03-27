module Mulukhiya
  class LongTextImageHandler < ImageHandler
    def disable?
      if Environment.production?
        return true unless today.month == 4
        return true unless today.day == 1
      end
      return super
    end

    def handle_pre_toot(body, params = {})
      @status = body[status_field] || ''
      return body if parser.command?
      return body unless executable?(body)
      return body unless path = create_image(@status)
      body[attachment_field] ||= []
      body[attachment_field].push(sns.upload(path, {response: :id}))
      body[status_field] = '.'
      result.push(message: "今日は#{today.month}月#{today.day}日です。")
      return body
    rescue => e
      errors.push(class: e.class.to_s, message: e.message)
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    def verbose?
      return true
    end

    def executable?(body)
      return false if attachment_limit <= (body[attachment_field] || []).count
      return text_length < body[status_field].length
    end

    private

    def create_image(text)
      image = MiniMagick::Image.open(image_path)
      image.combine_options do |magick|
        magick.font font_path
        magick.gravity 'center'
        magick.pointsize config['/handler/long_text_image/font_size']
        magick.draw %(text 0,0 '#{prepare_text(text)}')
      end
      path = File.join(Environment.dir, 'tmp/media', "#{text.adler32}.png")
      image.write(path)
      return path
    rescue => e
      logger.error(error: e)
      return nil
    end

    def image_path
      return File.join(Environment.dir, config['/handler/long_text_image/image_file'])
    end

    def font_path
      return File.join(Environment.dir, config['/handler/long_text_image/font_file'])
    end

    def columns
      return config['/handler/long_text_image/columns']
    end

    def rows
      return config['/handler/long_text_image/rows']
    end

    def today
      return Date.today
    end

    def prepare_text(text)
      return text.scan(/.{1,#{columns}}/o)[0...rows].join("\n")
    end

    def text_length
      return config['/handler/long_text_image/text_length']
    end
  end
end
