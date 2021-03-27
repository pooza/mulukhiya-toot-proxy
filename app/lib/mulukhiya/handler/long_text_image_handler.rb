module Mulukhiya
  class LongTextImageHandler < Handler
    def disable?
      # 4月1日以外でも動作させたいアホな^H^H^H人は、下2行をコメントアウトしてください。
      return true unless today.month == 4
      return true unless today.day == 1
      # コメントアウトはここまで。季節を問わずに楽しめるようになります。
      return super
    end

    def today
      return Date.today
    end

    def handle_pre_toot(body, params = {})
      return body unless executable?(body)
    end

    def executable?(body)
      # 本来は半角文字は0.5文字として数えるべきなどという苦情は受け付けません。
      # あのサービスの正しい仕様になど興味ないです。
      return max_length < body[status_field].length
    end

    def max_length
      return 140
    end
  end
end

# おまけの雑談です。
# 昨年は、エイプリルフールネタの準備が間に合わなかったんです。
# ちょうど100ワニが流行ってた（…流行ってた？）頃だったから、「ワニ語尾を強制するハンドラ」
# などという、叱られ必至のネタを考えていた。
# 「今日は良い天気ですね。」なんてトゥートすると「今日は良い天気ですねワニ！」なんて置き換える、
# 頭の悪すぎるネタだったから、お蔵入りになってよかったかもしれないけど。
#
# で、2021年のネタですが。
# 140文字を越える投稿を行うとそのテキストを画像に変換し、長文投稿を行える様になる便利機能です。
# 一発ネタとして楽しんでもらえるとうれしいけど、不謹慎厨や自治警察に叱られたり、
# 逆に「ちょうべんりですね！」なんてめっちゃ感謝されたら困っちゃいますね。
