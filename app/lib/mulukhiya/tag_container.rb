module Mulukhiya
  class TagContainer < Ginseng::Fediverse::TagContainer
    include Package

    # ⚠ **`sub` より先に UTF-8 を保証する (#4642)。** `sub` は不正なバイト列に対して
    # `ArgumentError` を上げるので、ここを素通りさせると基底の `add` が持つ検査
    # (pooza/ginseng-fediverse#248) へ届く前に落ちる。型も `ArgumentError` で
    # 捕まえにくく、入口で 400 に落とせない (#4600)。
    #
    # ⚠ **`filter_map` の `.presence` は基底と挙動が違うので残す。**空白だけの語を
    # 落とすのはこちら固有で、基底の `normalize` は空白を残す。
    def initialize(strings = [])
      strings = strings.to_a.filter_map do |v|
        case v
        in String
          self.class.to_utf8(v).sub(/^#/, '').presence
        else
          v
        end
      end
      super
    end

    def normalize(word)
      if rule = TaggingHandler.normalize_rules.find {|v| v['source'] == word.to_hashtag_base}
        word = rule['normalized']
      end
      return super
    end

    # ⚠⚠ **`self.scan` を上書きしない (#4642)。** 基底 (1.8.30) は入口で `to_utf8` を
    # 通すようになったが、こちらの上書きはそれを呼ばずに `text.scan` していたため、
    # **タグ抽出の主経路が丸ごとガードを迂回していた**。上書きは基底から
    # `to_utf8` を抜いただけの同一実装で、消しても `new` は
    # レシーバのクラス (= このクラス) を指すので挙動は変わらない。

    def self.default_tags
      return DefaultTagHandler.tags
    end

    def self.remote_default_tags
      return RemoteTagHandler.tags
    end

    def self.media_tags
      tags = new
      if handler = Handler.create(:media_tag)
        tags.merge(handler.all.to_h.values)
      end
      return tags
    end
  end
end
