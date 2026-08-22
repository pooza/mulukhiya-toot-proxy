module Mulukhiya
  class MultiFieldRemoteDictionary < RemoteDictionary
    # `[{field: 語, ...}, ...]` の Array。
    def expected_class
      return Array
    end

    # ⚠ **外側の rescue は 3 サブクラス揃えてある (#4573)。**以前ここだけ
    # rescue が無く、同じ 200-with-HTML を掴んでも related / mecab は静かに
    # `{}`、ここだけ NoMethodError が呼び出し元へ抜けていた。fail-open 自体は
    # 残す（一過性の障害で辞書が消し飛ぶのを防ぐ意図は正しい）が、**倒れたことが
    # 見えない**ほうを直す＝ fetch が型を検証して logger.error を残す。
    def parse
      result = {}
      fetch.each do |entry|
        fields.select {|v| entry[v]}.each do |field|
          result[create_key(entry[field])] ||= create_entry(entry[field])
        end
      rescue => e
        e.log(dic: uri.to_s, entry:)
      end
      return result
    rescue => e
      e.log(dic: uri.to_s)
      return {}
    end

    def fields
      @fields ||= @params['/fields'] || ['word']
      return @fields
    end
  end
end
