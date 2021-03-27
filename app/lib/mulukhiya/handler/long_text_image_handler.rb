# ■使い方
# 設置ディレクトリ/font ディレクトリ作成し、その中に適当なフォントを置く。
# （HackGenなら、設定もいじる必要がなくお勧め）
# 設定値 /handler/long_text_image/disable をfalseに。

module Mulukhiya
  class LongTextImageHandler < ImageHandler
    def disable?
      if Environment.production?
        # 本番環境で、4/1以外でも動作させたいアホな^H^H^H人は、下2行をコメントアウトしてください。
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
      return false if attachment_limit <= body[attachment_field].count

      # 本来は半角文字は0.5文字として数えるべきなどという苦情は受け付けません。
      # あのサービスの正しい仕様になど、作者は興味がないです。
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

# おまけの雑談です。
# 昨年は、エイプリルフールネタの準備が間に合わなかったんです。
# ちょうど100ワニが流行ってた（…流行ってた？）頃だったから、「ワニ語尾を強制するハンドラ」
# などという、叱られ発生が必至なネタを考えていた。
# 「今日は良い天気ですね。」ってトゥートすると「今日は良い天気ですねワニ！」なんて置き換える、
# 頭の悪すぎるネタだったから、実際にはお蔵入りになったのはよかったかもしれないけど。
#
# で、2021年のエイプリルフールネタですが。
# 140文字を越える投稿を行うとそのテキストを画像に変換し、長文投稿を行える様になる便利機能です。
# 一発ネタとして楽しんでもらえるとうれしいけど、不謹慎厨やら自治警察やらに叱られたり、
# 逆に「ちょうべんりですね！」なんてめっちゃ感謝されたら困っちゃいますね。
