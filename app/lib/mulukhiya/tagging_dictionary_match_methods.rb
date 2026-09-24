module Mulukhiya
  # タグ辞書の照合 (#4463)。TaggingDictionary 本体から切り出してある。
  #
  # ⚠ **投稿の同期経路に乗るのはこのモジュールだけ。**取り込み（Redis・リモート
  # 辞書の取得）とは費用の性質が違うので、所要を見るときはここだけ読めばよい。
  module TaggingDictionaryMatchMethods
    def matches(source)
      return TagContainer.new(match_words(source))
    end

    # 本文に当たった辞書エントリの words。
    #
    # ⚠⚠ **長い語から順に照合し、当たった語は本文から消し込む。**短い語が長い語の
    # 一部に当たらないようにするための仕様で、順序そのものに意味がある。
    #
    # ⚠ **並列にしない (#4463)。**以前は長さごとの塊を `Parallel.each` で回していたが、
    # 消し込みの `text =` がスレッド間で競合して**順序の保証が崩れていた**うえ、
    # 照合そのものは 3000 語で数 ms しかかからず、**スレッドを起こす費用のほうが
    # 10 倍以上大きかった**（Issue の実測）。
    def match_words(source)
      text = source.dup
      tags = []
      chunks.reverse_each do |chunk|
        chunk.each do |entry|
          next unless text.match?(entry[:pattern])
          tags.concat(entry[:words])
          text = text.gsub(entry[:pattern], '')
        rescue => e
          e.log(entry:)
        end
      end
      return tags.uniq
    end

    def short?(word)
      return true if word.match?(short_pattern)
      return word.length < minimum_length_kanji
    end

    private

    # 語の長さごとの塊を、短い順に並べたもの。
    # ⚠ **並びは明示的に揃える。**以前は並列に詰めた Hash の挿入順に頼っており、
    # 長い順に照合する前提がスレッドの進み具合次第だった (#4463)。
    def chunks
      chunks = {}
      keys.each do |k|
        next if short?(k)
        (chunks[k.length] ||= []).push(self[k])
      rescue => e
        e.log(k:)
      end
      return chunks.sort.map(&:last)
    end

    # ⚠ **short? は 1 回の照合で辞書の全語 (3000 語超) に掛かる (#4463)。**
    # 以前は語ごとに設定を 3 回引いて正規表現を作り直しており、照合本体より重かった。
    def short_pattern
      @short_pattern ||= Regexp.new(
        "^#{@handler.without_kanji_pattern}{,#{@handler.minimum_length - 1}}$",
      )
      return @short_pattern
    end

    def minimum_length_kanji
      @minimum_length_kanji ||= @handler.minimum_length_kanji
      return @minimum_length_kanji
    end
  end
end
